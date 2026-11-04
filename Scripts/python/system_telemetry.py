"""One-shot dashboard telemetry; GPU access is explicit and device-scoped."""
import argparse
import json
import math
from pathlib import Path
import re
import signal
import subprocess
import sys
import xml.etree.ElementTree as ET

MIB = 1024 * 1024
NVIDIA_TIMEOUT = 2


def read_text(path):
    try:
        return Path(path).read_text(errors="replace").strip()
    except OSError:
        return ""


def number(text, scale=1):
    match = re.fullmatch(r"\s*([+-]?(?:\d+(?:\.\d*)?|\.\d+))\s*(?:[%A-Za-z/]+)?\s*", text or "")
    if not match:
        return None
    value = float(match[1]) / scale
    return value if math.isfinite(value) and value >= 0 else None


def first_number(paths, scale=1):
    for path in paths:
        value = number(read_text(path), scale)
        if value is not None:
            return value
    return None


def system_data(proc=Path("/proc")):
    cpu_name = ""
    for line in read_text(proc / "cpuinfo").splitlines():
        key, separator, value = line.partition(":")
        if separator and key.strip() in ("model name", "Hardware", "Processor"):
            cpu_name = value.strip()
            break
    uptime_parts = read_text(proc / "uptime").split()
    uptime = number(uptime_parts[0]) if uptime_parts else None
    memory = {}
    for line in read_text(proc / "meminfo").splitlines():
        key, separator, value = line.partition(":")
        if separator:
            memory[key] = number(value.strip())
    cache = None
    if all(memory.get(key) is not None for key in ("Cached", "SReclaimable", "Shmem")):
        cache = max(0, memory["Cached"] + memory["SReclaimable"] - memory["Shmem"]) / (1024 * 1024)
    processes = []
    try:
        entries = proc.iterdir()
        for entry in entries:
            if not entry.name.isdecimal():
                continue
            status = read_text(entry / "status")
            name = ""
            rss = None
            for line in status.splitlines():
                if line.startswith("Name:"):
                    name = line.partition(":")[2].strip()
                elif line.startswith("VmRSS:"):
                    rss = number(line.partition(":")[2].strip(), 1024)
            if name and rss is not None:
                processes.append({"name": name, "memoryMiB": rss})
    except OSError:
        pass
    return {"cpuName": cpu_name, "uptime": uptime, "memCacheGb": cache,
            "processes": sorted(processes, key=lambda row: row["memoryMiB"], reverse=True)[:4], "gpu": None}


def empty_gpu():
    return dict.fromkeys(("name", "driver", "pcie", "state", "usage", "temp", "power", "powerLimit",
                          "vramUsedMiB", "vramTotalMiB", "coreClock", "memoryClock", "fan", "fanUnit",
                          "limitPower", "limitThermal", "limitHardware", "processes"))


def supported_text(value):
    value = (value or "").strip()
    if not value or value.lower() in ("n/a", "[n/a]", "not supported", "[not supported]", "unknown"):
        return None
    return value


def active_reason(gpu, names):
    values = [supported_text(gpu.findtext(f"{section}/{name}"))
              for section in ("clocks_event_reasons", "clocks_throttle_reasons") for name in names]
    known = [value.lower() for value in values if value is not None]
    if any(value in ("active", "yes", "true") for value in known):
        return True
    if known and all(value in ("not active", "no", "false") for value in known):
        return False
    return None


def parse_nvidia_xml(text):
    document = ET.fromstring(text)
    node = document.find("gpu")
    if node is None:
        return None
    result = empty_gpu()
    result.update(name=supported_text(node.findtext("product_name")),
                  driver=supported_text(document.findtext("driver_version")),
                  state=supported_text(node.findtext("performance_state")))
    fields = {
        "usage": ("utilization/gpu_util",), "temp": ("temperature/gpu_temp",),
        "power": ("gpu_power_readings/power_draw", "gpu_power_readings/instant_power_draw",
                  "gpu_power_readings/average_power_draw", "power_readings/power_draw"),
        "powerLimit": ("gpu_power_readings/power_limit", "gpu_power_readings/enforced_power_limit",
                       "power_readings/power_limit", "power_readings/enforced_power_limit"),
        "vramUsedMiB": ("fb_memory_usage/used",), "vramTotalMiB": ("fb_memory_usage/total",),
        "coreClock": ("clocks/graphics_clock",), "memoryClock": ("clocks/mem_clock",),
        "fan": ("fan_speed",)
    }
    for field, paths in fields.items():
        for path in paths:
            value = number(node.findtext(path))
            if value is not None:
                result[field] = value
                break
    if result["fan"] is not None:
        result["fanUnit"] = "%"
    generation = supported_text(node.findtext("pci/pci_gpu_link_info/pcie_gen/current_link_gen"))
    width = supported_text(node.findtext("pci/pci_gpu_link_info/link_widths/current_link_width"))
    if generation and width:
        result["pcie"] = f"PCIe {generation} · {width}"
    result["limitPower"] = active_reason(node, ("clocks_event_reason_sw_power_cap", "clocks_throttle_reason_sw_power_cap"))
    result["limitThermal"] = active_reason(node, ("clocks_event_reason_sw_thermal_slowdown", "clocks_event_reason_hw_thermal_slowdown",
                                                   "clocks_throttle_reason_sw_thermal_slowdown", "clocks_throttle_reason_hw_thermal_slowdown"))
    result["limitHardware"] = active_reason(node, ("clocks_event_reason_hw_slowdown", "clocks_event_reason_hw_power_brake_slowdown",
                                                    "clocks_throttle_reason_hw_slowdown", "clocks_throttle_reason_hw_power_brake_slowdown"))
    # XML includes both graphics and compute clients, unlike --query-compute-apps.
    processes = {}
    for process in node.findall("processes/process_info"):
        memory = number(process.findtext("used_memory"))
        pid = process.findtext("pid")
        name = supported_text(process.findtext("process_name"))
        if memory is None or not pid or not name:
            continue
        previous = processes.get(pid)
        if previous is None or memory > previous["memoryMiB"]:
            processes[pid] = {"name": Path(name).name, "memoryMiB": memory}
    if node.find("processes") is not None:
        result["processes"] = sorted(processes.values(), key=lambda row: row["memoryMiB"], reverse=True)[:4] if processes else (None if node.findall("processes/process_info") else [])
    return result


def nvidia_data():
    process = None
    try:
        process = subprocess.Popen(["nvidia-smi", "--id=0", "--query", "--xml-format"],
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        output, _ = process.communicate(timeout=NVIDIA_TIMEOUT)
        return parse_nvidia_xml(output) if process.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired, ET.ParseError):
        return None
    finally:
        # Also reap the driver query when QML cancels this collector with SIGTERM.
        if process is not None:
            if process.poll() is None:
                process.kill()
            process.wait()


def active_clock(path):
    for line in read_text(path).splitlines():
        if "*" in line:
            match = re.search(r"(\d+(?:\.\d+)?)\s*([MG])hz", line, re.IGNORECASE)
            if match:
                return float(match[1]) * (1000 if match[2].upper() == "G" else 1)
    return None


def drm_processes(device, proc=Path("/proc")):
    result = []
    # drm-pdev identifies the selected PCI device; never sum another adapter's clients.
    if not re.fullmatch(r"[\da-fA-F]{4}:[\da-fA-F]{2}:[\da-fA-F]{2}\.[\da-fA-F]", device.name):
        return None
    try:
        for process in proc.iterdir():
            if not process.name.isdecimal():
                continue
            clients = {}
            try:
                for info in (process / "fdinfo").iterdir():
                    fields = dict(line.split(":", 1) for line in read_text(info).splitlines() if ":" in line)
                    if fields.get("drm-pdev", "").strip().lower() != device.name.lower():
                        continue
                    client = fields.get("drm-client-id", "").strip()
                    if not client:
                        continue
                    # resident-vram is actual residency where exposed; older AMD exposes memory-vram.
                    value = fields.get("drm-resident-vram", fields.get("drm-memory-vram", "")).strip()
                    match = re.fullmatch(r"(\d+)\s+(KiB|MiB|bytes)", value)
                    if match:
                        factor = {"KiB": 1 / 1024, "MiB": 1, "bytes": 1 / MIB}[match[2]]
                        clients[client] = max(clients.get(client, 0), int(match[1]) * factor)
            except OSError:
                continue
            name = read_text(process / "comm")
            if clients and name:
                result.append({"name": name, "memoryMiB": sum(clients.values())})
    except OSError:
        pass
    return sorted(result, key=lambda row: row["memoryMiB"], reverse=True)[:4] if result else None


def pci_name(vendor, model):
    vendor, model = vendor.removeprefix("0x").lower(), model.removeprefix("0x").lower()
    if not vendor or not model:
        return None
    for path in ("/usr/share/hwdata/pci.ids", "/usr/share/misc/pci.ids", "/usr/share/pci.ids"):
        try:
            with open(path, errors="replace") as database:
                found_vendor = False
                for line in database:
                    if line.startswith("#") or not line.strip():
                        continue
                    if not line.startswith("\t"):
                        if found_vendor:
                            break
                        found_vendor = line[:4].lower() == vendor
                    elif found_vendor and not line.startswith("\t\t") and line[1:5].lower() == model:
                        return line[5:].strip()
        except OSError:
            continue
    return f"{vendor}:{model}"


def sysfs_data(hwmon, gpu_type):
    hwmon = Path(hwmon)
    if read_text(hwmon / "name") not in ({"amdgpu"} if gpu_type == "amd" else {"i915", "xe"}):
        return None
    try:
        device = (hwmon / "device").resolve(strict=True)
    except OSError:
        return None
    result = empty_gpu()
    result["name"] = supported_text(read_text(device / "product_name") or read_text(device / "marketing_name"))
    if result["name"] is None:
        vendor = read_text(device / "vendor")
        model = read_text(device / "device")
        result["name"] = pci_name(vendor, model)
    try:
        result["driver"] = (device / "driver").resolve(strict=True).name
    except OSError:
        pass
    states = [read_text(device / path) for path in ("power_dpm_state", "power_dpm_force_performance_level", "power/runtime_status")]
    result["state"] = " · ".join(dict.fromkeys(state for state in states if state)) or None
    speed, width = read_text(device / "current_link_speed"), read_text(device / "current_link_width")
    if speed and width and "unknown" not in speed.lower():
        result["pcie"] = f"{speed} · x{width}"
    result["usage"] = first_number([device / "gpu_busy_percent"])
    result["temp"] = first_number([hwmon / "temp1_input"], 1000)
    result["power"] = first_number([hwmon / "power1_average", hwmon / "power1_input"], 1000000)
    result["powerLimit"] = first_number([hwmon / "power1_cap"], 1000000)
    result["vramUsedMiB"] = first_number([device / "mem_info_vram_used"], MIB)
    result["vramTotalMiB"] = first_number([device / "mem_info_vram_total"], MIB)
    result["coreClock"] = active_clock(device / "pp_dpm_sclk")
    result["memoryClock"] = active_clock(device / "pp_dpm_mclk")
    if result["coreClock"] is None:
        result["coreClock"] = first_number([hwmon / "freq1_input"], 1000000)
    if gpu_type == "intel" and result["coreClock"] is None:
        paths = list((device / "drm").glob("card[0-9]*/gt_cur_freq_mhz"))
        paths += list((device / "tile0").glob("gt[0-9]*/freq0/cur_freq"))
        result["coreClock"] = first_number(paths)
    if result["memoryClock"] is None:
        result["memoryClock"] = first_number([hwmon / "freq2_input"], 1000000)
    result["fan"] = first_number([hwmon / "fan1_input"])
    if result["fan"] is not None:
        result["fanUnit"] = "RPM"
    result["processes"] = drm_processes(device)
    return result


def collect(gpu_type="", hwmon="", allow_dgpu=False, integrated=False):
    result = system_data()
    if gpu_type == "nvidia" and allow_dgpu:
        result["gpu"] = nvidia_data()
    elif gpu_type in ("amd", "intel") and hwmon and (allow_dgpu or (gpu_type == "amd" and integrated)):
        result["gpu"] = sysfs_data(hwmon, gpu_type)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gpu-type", choices=("amd", "intel", "nvidia"), default="")
    parser.add_argument("--hwmon", default="")
    parser.add_argument("--allow-dgpu", action="store_true")
    parser.add_argument("--integrated", action="store_true", help="Selected AMD sensor has no dedicated VRAM (from SystemStatService)")
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    print(json.dumps(collect(args.gpu_type, args.hwmon, args.allow_dgpu, args.integrated), allow_nan=False))


if __name__ == "__main__":
    main()

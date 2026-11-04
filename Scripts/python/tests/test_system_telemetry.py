import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import system_telemetry as telemetry


class GpuGatingTests(unittest.TestCase):
    def test_disabled_discrete_gpu_never_opens_driver_or_sysfs(self):
        with patch.object(telemetry, "system_data", return_value={"gpu": None}), \
                patch.object(telemetry, "nvidia_data") as nvidia, \
                patch.object(telemetry, "sysfs_data") as sysfs:
            for gpu_type in ("nvidia", "amd", "intel"):
                self.assertIsNone(telemetry.collect(gpu_type, "/selected/hwmon")["gpu"])
            nvidia.assert_not_called()
            sysfs.assert_not_called()
            telemetry.collect("amd", "/selected/hwmon", integrated=True)
            sysfs.assert_called_once_with("/selected/hwmon", "amd")

    def test_timed_out_or_cancelled_driver_query_is_reaped(self):
        for failure in (subprocess.TimeoutExpired("nvidia-smi", 2), SystemExit(0)):
            with self.subTest(failure=type(failure).__name__):
                process = Mock(returncode=None)
                process.communicate.side_effect = failure
                process.poll.return_value = None
                with patch.object(telemetry.subprocess, "Popen", return_value=process):
                    if isinstance(failure, SystemExit):
                        with self.assertRaises(SystemExit):
                            telemetry.nvidia_data()
                    else:
                        self.assertIsNone(telemetry.nvidia_data())
                process.kill.assert_called_once()
                process.wait.assert_called_once()


class NvidiaXmlTests(unittest.TestCase):
    def test_graphics_and_compute_clients_and_unsupported_fields(self):
        result = telemetry.parse_nvidia_xml("""<nvidia_smi_log>
          <driver_version>580.1</driver_version><gpu>
          <product_name>Test GPU</product_name><performance_state>P8</performance_state>
          <fan_speed>N/A</fan_speed><utilization><gpu_util>0 %</gpu_util></utilization>
          <gpu_power_readings><instant_power_draw>12.50 W</instant_power_draw></gpu_power_readings>
          <clocks_event_reasons><clocks_event_reason_sw_power_cap>Not Active</clocks_event_reason_sw_power_cap></clocks_event_reasons>
          <processes>
            <process_info><pid>11</pid><type>G</type><process_name>/usr/bin/compositor</process_name><used_memory>250 MiB</used_memory></process_info>
            <process_info><pid>12</pid><type>C</type><process_name>/usr/bin/compute</process_name><used_memory>500 MiB</used_memory></process_info>
            <process_info><pid>12</pid><type>G+C</type><process_name>/usr/bin/compute</process_name><used_memory>500 MiB</used_memory></process_info>
            <process_info><pid>13</pid><type>G</type><process_name>unknown</process_name><used_memory>N/A</used_memory></process_info>
          </processes></gpu></nvidia_smi_log>""")
        self.assertEqual(result["usage"], 0)
        self.assertEqual(result["power"], 12.5)
        self.assertIsNone(result["fan"])
        self.assertIsNone(result["fanUnit"])
        self.assertIsNone(result["temp"])
        self.assertFalse(result["limitPower"])
        self.assertIsNone(result["limitThermal"])
        self.assertIsNone(result["limitHardware"])
        self.assertEqual(result["processes"], [{"name": "compute", "memoryMiB": 500},
                                                 {"name": "compositor", "memoryMiB": 250}])
        json.dumps(result, allow_nan=False)

    def test_unknown_process_memory_is_not_an_empty_client_list(self):
        unavailable = """<nvidia_smi_log><gpu><processes><process_info>
          <pid>13</pid><process_name>renderer</process_name><used_memory>N/A</used_memory>
          </process_info></processes></gpu></nvidia_smi_log>"""
        self.assertIsNone(telemetry.parse_nvidia_xml(unavailable)["processes"])
        self.assertEqual(telemetry.parse_nvidia_xml(
            "<nvidia_smi_log><gpu><processes/></gpu></nvidia_smi_log>")["processes"], [])
        self.assertIsNone(telemetry.parse_nvidia_xml(
            "<nvidia_smi_log><gpu/></nvidia_smi_log>")["processes"])



class AmdSysfsTests(unittest.TestCase):
    def test_units_active_clocks_real_zero_and_null_limit_flags(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            hwmon, device = root / "hwmon1", root / "0000:2f:00.0"
            hwmon.mkdir()
            device.mkdir()
            (hwmon / "device").symlink_to(device, target_is_directory=True)
            for name, value in {"name": "amdgpu", "power1_average": "22000000", "power1_cap": "160000000",
                                "fan1_input": "0", "temp1_input": "42000"}.items():
                (hwmon / name).write_text(value)
            for name, value in {"product_name": "Selected AMD GPU", "gpu_busy_percent": "13",
                                "mem_info_vram_used": "1073741824", "mem_info_vram_total": "17179869184",
                                "pp_dpm_sclk": "0: 500Mhz\n1: 1631Mhz *\n2: 2620Mhz",
                                "pp_dpm_mclk": "0: 96Mhz\n1: 875Mhz *"}.items():
                (device / name).write_text(value)
            with patch.object(telemetry, "drm_processes", return_value=[]):
                result = telemetry.sysfs_data(hwmon, "amd")
            self.assertEqual(result["name"], "Selected AMD GPU")
            self.assertEqual((result["power"], result["powerLimit"]), (22, 160))
            self.assertEqual((result["vramUsedMiB"], result["vramTotalMiB"]), (1024, 16384))
            self.assertEqual((result["coreClock"], result["memoryClock"]), (1631, 875))
            self.assertEqual((result["fan"], result["fanUnit"]), (0, "RPM"))
            self.assertEqual(result["temp"], 42)
            for field in ("limitPower", "limitThermal", "limitHardware", "driver", "pcie"):
                self.assertIsNone(result[field])
            json.dumps(result, allow_nan=False)

    def test_drm_clients_are_deduplicated_and_device_scoped(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            process = root / "123"
            (process / "fdinfo").mkdir(parents=True)
            (process / "comm").write_text("compositor")
            selected = "drm-pdev: 0000:2f:00.0\ndrm-client-id: 8\ndrm-memory-vram: 2048 KiB\n"
            (process / "fdinfo/10").write_text(selected)
            (process / "fdinfo/11").write_text(selected)
            (process / "fdinfo/12").write_text(selected.replace("2f:00.0", "03:00.0"))
            result = telemetry.drm_processes(Path("/sys/devices/0000:2f:00.0"), root)
            self.assertEqual(result, [{"name": "compositor", "memoryMiB": 2}])

    def test_missing_drm_accounting_stays_unknown(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "123/fdinfo").mkdir(parents=True)
            (root / "123/comm").write_text("renderer")
            (root / "123/fdinfo/10").write_text(
                "drm-pdev: 0000:2f:00.0\ndrm-client-id: 8\n")
            self.assertIsNone(telemetry.drm_processes(Path("/sys/devices/0000:2f:00.0"), root))



if __name__ == "__main__":
    unittest.main()

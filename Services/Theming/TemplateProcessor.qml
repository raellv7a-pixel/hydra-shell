pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Services.System
import qs.Services.Theming
import qs.Services.UI

Singleton {
  id: root

  // Signal emitted when color generation completes successfully (for wallpaper-based theming)
  signal colorsGenerated

  readonly property string dynamicConfigPath: Settings.cacheDir + "theming.dynamic.toml"
  readonly property string templateProcessorScript: Quickshell.shellDir + "/Scripts/python/src/theming/template-processor.py"

  // Debounce state for wallpaper processing
  property var pendingWallpaperRequest: null
  property var pendingPredefinedRequest: null

  readonly property var materialSchemeKeys: ["smart", "tonal-spot", "content", "expressive", "fidelity", "neutral", "m3-vibrant", "fruit-salad", "rainbow", "monochrome"]
  readonly property var schemeTypes: [
    {
      "key": "smart",
      "name": "Smart"
    },
    {
      "key": "tonal-spot",
      "name": "M3-Tonal Spot"
    },
    {
      "key": "content",
      "name": "M3-Content"
    },
    {
      "key": "expressive",
      "name": "M3-Expressive"
    },
    {
      "key": "fidelity",
      "name": "M3-Fidelity"
    },
    {
      "key": "neutral",
      "name": "M3-Neutral"
    },
    {
      "key": "m3-vibrant",
      "name": "M3 Vibrant"
    },
    {
      "key": "fruit-salad",
      "name": "M3-Fruit Salad"
    },
    {
      "key": "rainbow",
      "name": "M3-Rainbow"
    },
    {
      "key": "monochrome",
      "name": "M3-Monochrome"
    },
    {
      "key": "faithful",
      "name": I18n.tr("common.faithful") + " · Hydra"
    },
    {
      "key": "muted",
      "name": I18n.tr("common.color-muted") + " · Hydra"
    },
    {
      "key": "dysfunctional",
      "name": I18n.tr("common.dysfunctional") + " · Hydra"
    },
    {
      "key": "vibrant",
      "name": I18n.tr("common.vibrant") + " · Hydra"
    }
  ]

  // Check if a template is enabled in the activeTemplates array
  function isTemplateEnabled(templateId) {
    const activeTemplates = Settings.data.templates.activeTemplates;
    if (!activeTemplates)
      return false;
    for (let i = 0; i < activeTemplates.length; i++) {
      if (activeTemplates[i].id === templateId && activeTemplates[i].enabled) {
        return true;
      }
    }
    return false;
  }

  function escapeTomlString(value) {
    if (!value)
      return "";
    return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  }

  /**
  * Process wallpaper colors using internal themer
  * Dual-path architecture (wallpaper generation)
  * Uses debouncing to prevent spawning multiple processes when spamming wallpaper changes
  */
  function processWallpaperColors(wallpaperPath, mode) {
    Logger.d("TemplateProcessor", `processWallpaperColors called: path=${wallpaperPath}, mode=${mode}`);
    pendingWallpaperRequest = {
      wallpaperPath: wallpaperPath,
      mode: mode
    };
    pendingPredefinedRequest = null;
    debounceTimer.restart();
  }

  function executeWallpaperColors(wallpaperPath, mode) {
    Logger.d("TemplateProcessor", `executeWallpaperColors: path=${wallpaperPath}, mode=${mode}`);
    const content = buildThemeConfig();
    if (!content && !Settings.data.templates.enableUserTheming) {
      Logger.d("TemplateProcessor", "executeWallpaperColors: no config content and no user theming, aborting");
      return;
    }
    const script = buildGenerationScript(content, wallpaperPath, mode);

    generateProcess.command = ["sh", "-c", script];
    generateProcess.running = true;
  }

  readonly property string schemeJsonPath: Settings.cacheDir + "predefined-scheme.json"
  readonly property string predefinedConfigPath: Settings.cacheDir + "theming.predefined.toml"

  /**
  * Process predefined color scheme using Python template processor
  * Uses --scheme flag to expand 14-color scheme to full 48-color palette
  * Uses debouncing to prevent spawning multiple processes when spamming scheme changes
  */
  function processPredefinedScheme(schemeData, mode, wallpaperPath) {
    pendingPredefinedRequest = {
      schemeData: schemeData,
      mode: mode,
      wallpaperPath: wallpaperPath || ""
    };
    pendingWallpaperRequest = null;
    debounceTimer.restart();
  }

  function executePredefinedScheme(schemeData, mode, wallpaperPath) {
    // 1. Build TOML config for application templates (including terminals)
    const tomlContent = buildPredefinedTemplateConfig(mode);
    if (!tomlContent && !Settings.data.templates.enableUserTheming) {
      Logger.d("TemplateProcessor", "No application templates enabled for predefined scheme");
      return;
    }

    // 3. Build script to write files and run Python
    const schemeJsonPathEsc = schemeJsonPath.replace(/'/g, "'\\''");

    let script = "";

    // Write scheme JSON (needed by both built-in and user templates)
    const schemeDelimiter = "SCHEME_JSON_EOF_" + Math.random().toString(36).substr(2, 9);
    script += `cat > '${schemeJsonPathEsc}' << '${schemeDelimiter}'\n`;
    script += JSON.stringify(schemeData, null, 2) + "\n";
    script += `${schemeDelimiter}\n`;

    // Run built-in template processor only if there are templates configured
    if (tomlContent) {
      const configPathEsc = predefinedConfigPath.replace(/'/g, "'\\''");
      const tomlDelimiter = "TOML_CONFIG_EOF_" + Math.random().toString(36).substr(2, 9);

      // Write TOML config
      script += `cat > '${configPathEsc}' << '${tomlDelimiter}'\n`;
      script += tomlContent + "\n";
      script += `${tomlDelimiter}\n`;

      // Run Python template processor with --scheme flag
      // Don't pass --mode so templates get both dark and light colors (e.g., zed.json needs both)
      // Pass --default-mode so "default" in templates resolves to the current theme mode
      // Pass wallpaper as positional arg so image_path is available in templates (no extraction occurs when --scheme is used)
      const wpArg = wallpaperPath ? `'${wallpaperPath.replace(/'/g, "'\\''")}'` : "";
      script += `python3 "${templateProcessorScript}" ${wpArg} --scheme '${schemeJsonPathEsc}' --config '${configPathEsc}' --default-mode ${mode}\n`;
    }

    // Add user templates if enabled
    script += buildUserTemplateCommandForPredefined(schemeData, mode, wallpaperPath);

    generateProcess.command = ["sh", "-c", script];
    generateProcess.running = true;
  }

  /**
  * Build TOML config for predefined scheme templates (excludes terminal themes)
  */
  function buildPredefinedTemplateConfig(mode) {
    var lines = [];
    const homeDir = Quickshell.env("HOME");

    // Add terminal templates
    TemplateRegistry.terminals.forEach(terminal => {
                                         if (isTemplateEnabled(terminal.id)) {
                                           lines.push(`\n[templates.${terminal.id}]`);
                                           lines.push(`input_path = "${Quickshell.shellDir}/Assets/Templates/${terminal.predefinedTemplatePath}"`);
                                           const outputPath = terminal.outputPath.replace("~", homeDir);
                                           lines.push(`output_path = "${outputPath}"`);
                                           const postHookEsc = escapeTomlString(terminal.postHook);
                                           lines.push(`post_hook = "${postHookEsc}"`);
                                         }
                                       });

    addApplicationTheming(lines, mode);

    if (lines.length > 0) {
      return ["[config]"].concat(lines).join("\n") + "\n";
    }
    return "";
  }

  // ================================================================================
  // WALLPAPER-BASED GENERATION
  // ================================================================================
  function buildThemeConfig() {
    var lines = [];
    var mode = Settings.data.colorSchemes.darkMode ? "dark" : "light";

    if (Settings.data.colorSchemes.useWallpaperColors) {
      addWallpaperTheming(lines, mode);
    }

    addApplicationTheming(lines, mode);

    if (lines.length > 0) {
      return ["[config]"].concat(lines).join("\n") + "\n";
    }
    return "";
  }

  function addWallpaperTheming(lines, mode) {
    const homeDir = Quickshell.env("HOME");
    // Hydra colors JSON
    lines.push("[templates.hydra]");
    lines.push('input_path = "' + Quickshell.shellDir + '/Assets/Templates/hydra.json"');
    lines.push('output_path = "' + Settings.configDir + 'colors.json"');

    // Terminal templates
    TemplateRegistry.terminals.forEach(terminal => {
                                         if (isTemplateEnabled(terminal.id)) {
                                           lines.push(`\n[templates.${terminal.id}]`);
                                           lines.push(`input_path = "${Quickshell.shellDir}/Assets/Templates/${terminal.templatePath}"`);
                                           const outputPath = terminal.outputPath.replace("~", homeDir);
                                           lines.push(`output_path = "${outputPath}"`);
                                           const postHookEsc = escapeTomlString(terminal.postHook);
                                           lines.push(`post_hook = "${postHookEsc}"`);
                                         }
                                       });
  }

  function addTemplateColorMatching(lines, app) {
    if (!app.colorsToCompare || !app.compareTo)
      return;

    const candidates = app.colorsToCompare.map(candidate => `{ name = "${escapeTomlString(candidate.name)}", color = "${escapeTomlString(candidate.color)}" }`);
    lines.push(`colors_to_compare = [${candidates.join(", ")}]`);
    lines.push(`compare_to = "${escapeTomlString(app.compareTo)}"`);
  }

  function addApplicationTheming(lines, mode) {
    const homeDir = Quickshell.env("HOME");
    TemplateRegistry.applications.forEach(app => {
                                            if (app.id === "discord") {
                                              // Handle Discord clients specially - multiple CSS themes
                                              if (isTemplateEnabled("discord")) {
                                                const inputs = Array.isArray(app.input) ? app.input : [app.input];
                                                inputs.forEach((inputFile, idx) => {
                                                                 // Derive theme suffix from input filename: discord-midnight.css → midnight
                                                                 const themeSuffix = inputFile.replace(/^discord-/, "").replace(/\.css$/, "");
                                                                 app.clients.forEach(client => {
                                                                                       if (isDiscordClientEnabled(client.name)) {
                                                                                         lines.push(`\n[templates.discord_${themeSuffix}_${client.name}]`);
                                                                                         lines.push(`input_path = "${Quickshell.shellDir}/Assets/Templates/${inputFile}"`);
                                                                                         // First input uses legacy name for backward compatibility
                                                                                         const outputFile = idx === 0 ? "hydra.theme.css" : `hydra-${themeSuffix}.theme.css`;
                                                                                         const outputPath = client.path.replace("~", homeDir) + `/themes/${outputFile}`;
                                                                                         lines.push(`output_path = "${outputPath}"`);
                                                                                       }
                                                                                     });
                                                               });
                                              }
                                            } else if (app.id === "code") {
                                              // Handle Code clients specially
                                              if (isTemplateEnabled("code")) {
                                                app.clients.forEach(client => {
                                                                      // Check if this specific client is detected
                                                                      var resolvedPaths = TemplateRegistry.resolvedCodeClientPaths(client.name);
                                                                      if (isCodeClientEnabled(client.name) && resolvedPaths.length > 0) {
                                                                        resolvedPaths.forEach((resolvedPath, pathIndex) => {
                                                                                                var suffix = resolvedPaths.length > 1 ? `_${pathIndex}` : "";
                                                                                                lines.push(`\n[templates.code_${client.name}${suffix}]`);
                                                                                                lines.push(`input_path = "${Quickshell.shellDir}/Assets/Templates/${app.input}"`);
                                                                                                lines.push(`output_path = "${resolvedPath}"`);
                                                                                              });
                                                                      }
                                                                    });
                                              }
                                            } else if (app.id === "emacs") {
                                              if (isTemplateEnabled("emacs")) {
                                                ProgramCheckerService.availableEmacsClients.forEach(client => {
                                                                                                      lines.push(`\n[templates.emacs_${client.name}]`);
                                                                                                      lines.push(`input_path = "${Quickshell.shellDir}/Assets/Templates/${app.input}"`);
                                                                                                      const expandedPath = client.path.replace("~", homeDir) + "/themes/hydra-theme.el";
                                                                                                      lines.push(`output_path = "${expandedPath}"`);
                                                                                                      if (app.postProcess) {
                                                                                                        const postHook = escapeTomlString(app.postProcess(mode));
                                                                                                        lines.push(`post_hook = "${postHook}"`);
                                                                                                      }
                                                                                                    });
                                              }
                                            } else {
                                              // Handle regular apps
                                              if (isTemplateEnabled(app.id)) {
                                                app.outputs.forEach((output, idx) => {
                                                                      lines.push(`\n[templates.${app.id}_${idx}]`);
                                                                      const inputFile = output.input || app.input;
                                                                      lines.push(`input_path = "${Quickshell.shellDir}/Assets/Templates/${inputFile}"`);
                                                                      const outputPath = output.path.replace("~", homeDir);
                                                                      lines.push(`output_path = "${outputPath}"`);
                                                                      addTemplateColorMatching(lines, app);
                                                                      if (app.postProcess && output.postProcess !== false) {
                                                                        const postHook = escapeTomlString(app.postProcess(mode));
                                                                        lines.push(`post_hook = "${postHook}"`);
                                                                      }
                                                                    });
                                              }
                                            }
                                          });
  }

  function isDiscordClientEnabled(clientName) {
    // Check ProgramCheckerService to see if client is detected
    for (var i = 0; i < ProgramCheckerService.availableDiscordClients.length; i++) {
      if (ProgramCheckerService.availableDiscordClients[i].name === clientName) {
        return true;
      }
    }
    return false;
  }

  function isCodeClientEnabled(clientName) {
    // Check ProgramCheckerService to see if client is detected
    for (var i = 0; i < ProgramCheckerService.availableCodeClients.length; i++) {
      if (ProgramCheckerService.availableCodeClients[i].name === clientName) {
        return true;
      }
    }
    return false;
  }

  // ================================================================================
  // PREVIEW — read-only palette computation, no templates/files touched
  // ================================================================================
  // Maps the snake_case keys template-processor.py returns to the "m*" keys that
  // feed colors.json / Commons/Color.qml, per Assets/Templates/hydra.json.
  // Surface containers are transported explicitly; accent containers remain
  // derived locally in Commons/Color.qml.
  readonly property var colorKeyMap: ({
                                        "mPrimary": "primary",
                                        "mOnPrimary": "on_primary",
                                        "mSecondary": "secondary",
                                        "mOnSecondary": "on_secondary",
                                        "mTertiary": "tertiary",
                                        "mOnTertiary": "on_tertiary",
                                        "mError": "error",
                                        "mOnError": "on_error",
                                        "mSurface": "surface",
                                        "mOnSurface": "on_surface",
                                        "mSurfaceVariant": "surface_variant",
                                        "mSurfaceContainerLowest": "surface_container_lowest",
                                        "mSurfaceContainerLow": "surface_container_low",
                                        "mSurfaceContainer": "surface_container",
                                        "mSurfaceContainerHigh": "surface_container_high",
                                        "mSurfaceContainerHighest": "surface_container_highest",
                                        "mPrimaryContainer": "primary_container",
                                        "mOnPrimaryContainer": "on_primary_container",
                                        "mSecondaryContainer": "secondary_container",
                                        "mOnSecondaryContainer": "on_secondary_container",
                                        "mTertiaryContainer": "tertiary_container",
                                        "mOnTertiaryContainer": "on_tertiary_container",
                                        "mOnSurfaceVariant": "on_surface_variant",
                                        "mOutline": "outline_variant",
                                        "mShadow": "shadow",
                                        "mHover": "tertiary",
                                        "mOnHover": "on_tertiary"
                                      })

  function mapToColorKeys(pythonDict) {
    if (!pythonDict)
      return null;
    var mapped = {};
    for (var qmlKey in colorKeyMap) {
      var pyKey = colorKeyMap[qmlKey];
      if (pythonDict[pyKey] !== undefined) {
        mapped[qmlKey] = pythonDict[pyKey];
      }
    }
    return mapped;
  }

  Component {
    id: previewProcessComponent

    Process {
      id: previewProcess

      property var callback: null

      stdout: StdioCollector {}
      stderr: StdioCollector {}

      onExited: function (exitCode, exitStatus) {
        const cb = previewProcess.callback;
        let result = null;
        if (exitCode === 0) {
          try {
            const parsed = JSON.parse(previewProcess.stdout.text);
            result = {
              "dark": parsed.dark || null,
              "light": parsed.light || null,
              "surfaceStyle": parsed._surface_style || "classic",
              "recommendedMode": parsed._recommended_mode || null,
              "candidates": parsed._source_candidates || [],
              "seedIndex": parsed._seed_index || 0,
              "effectiveModel": parsed._effective_scheme_type || "",
              "materialSpec": parsed._material_spec || "2025",
              "effectiveMaterialSpec": parsed._effective_material_spec || null
            };
          } catch (e) {
            Logger.w("TemplateProcessor", "previewWallpaperPalette: failed to parse output:", e);
          }
        } else {
          Logger.w("TemplateProcessor", "previewWallpaperPalette: process exited with code", exitCode, previewProcess.stderr.text);
        }
        // Leave the Process.onExited stack before destroying the dynamic object.
        Qt.callLater(() => {
                       previewProcess.destroy();
                     });
        if (cb) {
          cb(result);
        }
      }
    }
  }

  /**
  * Compute the full dark+light palette (and a recommended dark/light mode) for a
  * wallpaper WITHOUT touching colors.json, templates, or any application theming —
  * read-only, no side effects. Used for candidate previews and the smart mode decision.
  * callback receives { dark, light, recommendedMode } (Python's raw snake_case keys —
  * pass through mapToColorKeys() for the "m*" keys) or null on failure.
  */
  function previewWallpaperPalette(wallpaperPath, recipe, callback) {
    if (!wallpaperPath) {
      callback(null);
      return;
    }
    const process = previewProcessComponent.createObject(root, {
                                                           "callback": callback
                                                         });
    if (!process) {
      callback(null);
      return;
    }
    process.command = ["python3", templateProcessorScript, wallpaperPath, "--scheme-type", recipe.generationMethod, "--seed-index", String(recipe.seedIndex), "--material-spec", recipe.materialSpec === "2021" ? "2021" : "2025", "--surface-style", recipe.surfaceStyle];
    process.running = true;
    return process;
  }

  // Get scheme type, defaulting to tonal-spot if not a recognized value
  function getSchemeType() {
    const method = Settings.data.colorSchemes.generationMethod;
    const validKeys = root.schemeTypes.map(scheme => scheme.key);
    return validKeys.includes(method) ? method : "tonal-spot";
  }

  function getSurfaceStyle() {
    return Settings.data.colorSchemes.useWallpaperColors && Settings.data.colorSchemes.surfaceStyle === "tinted" ? "tinted" : "classic";
  }

  function getMaterialSpec() {
    return Settings.data.colorSchemes.materialSpec === "2021" ? "2021" : "2025";
  }

  function getRecipe() {
    return {
      generationMethod: getSchemeType(),
      surfaceStyle: Settings.data.colorSchemes.surfaceStyle === "tinted" ? "tinted" : "classic",
      seedIndex: Math.max(0, Settings.data.colorSchemes.seedIndex),
      materialSpec: getMaterialSpec()
    };
  }

  function buildGenerationScript(content, wallpaper, mode) {
    const pathEsc = dynamicConfigPath.replace(/'/g, "'\\''");
    const wpDelimiter = "WALLPAPER_PATH_EOF_" + Math.random().toString(36).substr(2, 9);

    // Use heredoc for wallpaper path to avoid all escaping issues
    let script = `HYDRA_WP_PATH=$(cat << '${wpDelimiter}'\n${wallpaper}\n${wpDelimiter}\n)\n`;

    // Run built-in template processor only if there are templates configured
    if (content) {
      const delimiter = "THEME_CONFIG_EOF_" + Math.random().toString(36).substr(2, 9);
      script += `cat > '${pathEsc}' << '${delimiter}'\n${content}\n${delimiter}\n`;

      // Use template-processor.py (Python implementation)
      // Don't pass --mode so templates get both dark and light colors (e.g., zed.json needs both)
      // Pass --default-mode so "default" in templates resolves to the current theme mode
      const schemeType = getSchemeType();
      script += `python3 "${templateProcessorScript}" "$HYDRA_WP_PATH" --scheme-type ${schemeType} --seed-index ${getRecipe().seedIndex} --material-spec ${getMaterialSpec()} --surface-style ${getSurfaceStyle()} --config '${pathEsc}' --default-mode ${mode}\n`;
    }

    script += buildUserTemplateCommand("$HYDRA_WP_PATH", mode);

    return script + "\n";
  }

  // ================================================================================
  // USER TEMPLATES, advanced usage
  // ================================================================================
  function buildUserTemplateCommand(input, mode) {
    if (!Settings.data.templates.enableUserTheming)
      return "";

    const userConfigPath = getUserConfigPath();
    let script = "\n# Execute user config if it exists\n";
    script += `if [ -f '${userConfigPath}' ]; then\n`;
    // If input is a shell variable (starts with $), use double quotes to allow expansion
    // Otherwise, use single quotes for safety with file paths
    const inputQuoted = input.startsWith("$") ? `"${input}"` : `'${input.replace(/'/g, "'\\''")}'`;

    const schemeType = getSchemeType();
    // Don't pass --mode so user templates get both dark and light colors
    // Pass --default-mode so "default" in templates resolves to the current theme mode
    script += `  python3 "${templateProcessorScript}" ${inputQuoted} --scheme-type ${schemeType} --seed-index ${getRecipe().seedIndex} --material-spec ${getMaterialSpec()} --surface-style ${getSurfaceStyle()} --config '${userConfigPath}' --default-mode ${mode}\n`;
    script += "fi";

    return script;
  }

  function buildUserTemplateCommandForPredefined(schemeData, mode, wallpaperPath) {
    if (!Settings.data.templates.enableUserTheming)
      return "";

    const userConfigPath = getUserConfigPath();

    // Reuse the scheme JSON already written by processPredefinedScheme()
    const schemeJsonPathEsc = schemeJsonPath.replace(/'/g, "'\\''");
    const wpArg = wallpaperPath ? `'${wallpaperPath.replace(/'/g, "'\\''")}'` : "";

    let script = "\n# Execute user templates with predefined scheme colors\n";
    script += `if [ -f '${userConfigPath}' ]; then\n`;
    // Use --scheme flag with the already-written scheme JSON
    // Don't pass --mode so user templates get both dark and light colors
    // Pass --default-mode so "default" in templates resolves to the current theme mode
    // Pass wallpaper as positional arg so image_path is available in templates
    script += `  python3 "${templateProcessorScript}" ${wpArg} --scheme '${schemeJsonPathEsc}' --config '${userConfigPath}' --default-mode ${mode}\n`;
    script += "fi";

    return script;
  }

  function getUserConfigPath() {
    return (Settings.configDir + "user-templates.toml").replace(/'/g, "'\\''");
  }

  // ================================================================================
  // DEBOUNCE TIMER
  // ================================================================================
  function executePendingRequest() {
    Logger.d("TemplateProcessor", `executePendingRequest: hasWallpaper=${!!pendingWallpaperRequest}, hasPredefined=${!!pendingPredefinedRequest}`);
    if (pendingWallpaperRequest) {
      const req = pendingWallpaperRequest;
      pendingWallpaperRequest = null;
      executeWallpaperColors(req.wallpaperPath, req.mode);
    } else if (pendingPredefinedRequest) {
      const req = pendingPredefinedRequest;
      pendingPredefinedRequest = null;
      executePredefinedScheme(req.schemeData, req.mode, req.wallpaperPath);
    } else {
      Logger.d("TemplateProcessor", "executePendingRequest: no pending request");
    }
  }

  Timer {
    id: debounceTimer
    interval: 150
    repeat: false
    onTriggered: {
      Logger.d("TemplateProcessor", `debounceTimer fired: processRunning=${generateProcess.running}`);
      // Kill any running process before starting new one
      if (generateProcess.running) {
        Logger.d("TemplateProcessor", "debounceTimer: stopping running process");
        generateProcess.running = false;
        // executePendingRequest will be called from onExited
      } else {
        executePendingRequest();
      }
    }
  }

  // ================================================================================
  // PROCESSES
  // ================================================================================
  Process {
    id: generateProcess
    workingDirectory: Quickshell.shellDir
    running: false

    onExited: function (exitCode, exitStatus) {
      // Execute any pending request (handles both kill case and debounce timer interval case)
      if (pendingWallpaperRequest || pendingPredefinedRequest) {
        Logger.d("TemplateProcessor", "generateProcess onExited: has pending request, executing");
        executePendingRequest();
      } else if (exitCode === 0) {
        // No pending request and successful completion - emit signal
        root.colorsGenerated();
      }
    }

    stderr: StdioCollector {
      onStreamFinished: {
        const text = this.text.trim();
        if (text && text.includes("Template error:")) {
          const errorLines = text.split("\n").filter(l => l.includes("Template error:"));
          const errors = errorLines.slice(0, 3).join("\n") + (errorLines.length > 3 ? `\n... (+${errorLines.length - 3} more)` : "");
          Logger.w("TemplateProcessor", errors);
          ToastService.showWarning(I18n.tr("toast.theming-processor-failed.title"), errors);
        }
      }
    }
  }
}

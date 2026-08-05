### Noctalia Plugin Configuration
Plugins in Noctalia are configured within `settings.toml`. 
They must first be enabled in the `[plugins]` array (e.g., `enabled = [ "noctalia/bitwarden", "noctalia/timer" ]`).
Their specific configuration keys are placed under TOML table headers matching the plugin's name, formatted as `[plugin_settings."<author>/<plugin>"]`.

For example, a valid configuration for Bitwarden looks like:
```toml
[plugin_settings."noctalia/bitwarden"]
server_url = "https://vault.bitwarden.com"
```

### The `std::optional` Unwrap Error
In `~/dotfiles/noctalia/settings.toml`, if the plugin sections are defined but left entirely empty:
```toml
[plugin_settings."noctalia/bitwarden"]

[plugin_settings."noctalia/timer"]
```
The crash occurs because the C++ TOML configuration parser expects certain keys and attempts to unwrap them using `std::optional`. When these keys are missing from the configuration file, the `std::optional` is empty. The Noctalia code tries to access its value (e.g., via `.value()`) without first checking `.has_value()`, triggering the C++ Standard Library assertion `Assertion 'this->_M_is_engaged()' failed`.

**Sources Checked:**
- `~/dotfiles/noctalia/settings.toml`
- `~/.local/state/noctalia/settings.toml`

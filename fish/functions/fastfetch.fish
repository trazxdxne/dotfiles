function fastfetch --description 'Run fastfetch with auto-detected disks'
    # 1. Detect root model
    set -l root_dev (findmnt -no SOURCE -M / 2>/dev/null | string replace -r '\[.*\]' '')
    set -l root_model ""
    if test -n "$root_dev"
        set -l root_parent (lsblk -no pkname $root_dev 2>/dev/null)
        if test -z "$root_parent"
            set root_parent (basename $root_dev)
        end
        set -l model (cat /sys/block/$root_parent/device/model 2>/dev/null | string trim)
        if test -z "$model"
            set model (lsblk -dno model $root_dev 2>/dev/null | string trim)
        end
        if test -n "$model"
            set root_model $model
        end
    end
    if test -z "$root_model"
        set root_model "System Drive"
    end

    # 2. Detect HDD_Linux model
    set -l hdd_dev (findmnt -no SOURCE -M /mnt/HDD_Linux 2>/dev/null | string replace -r '\[.*\]' '')
    set -l hdd_model ""
    if test -n "$hdd_dev"
        set -l hdd_parent (lsblk -no pkname $hdd_dev 2>/dev/null)
        if test -z "$hdd_parent"
            set hdd_parent (basename $hdd_dev)
        end
        set -l model (cat /sys/block/$hdd_parent/device/model 2>/dev/null | string trim)
        if test -z "$model"
            set model (lsblk -dno model $hdd_dev 2>/dev/null | string trim)
        end
        if test -n "$model"
            set hdd_model $model
        end
    end

    # 3. Build the disk modules block
    set -l disks_json "    {
      \"type\": \"disk\",
      \"folders\": \"/\",
      \"key\": \"│ 󱛟 $root_model (/)\",
      \"keyColor\": \"green\"
    }"

    if test -n "$hdd_dev" -a -n "$hdd_model"
        set disks_json "$disks_json,
    {
      \"type\": \"disk\",
      \"folders\": \"/mnt/HDD_Linux\",
      \"key\": \"│ 󱛟 $hdd_model (/mnt/HDD_Linux)\",
      \"keyColor\": \"green\"
    }"
    end

    # 4. Generate config.jsonc from template
    set -l template_file "$HOME/.config/fastfetch/config.jsonc.template"
    set -l config_file "$HOME/.config/fastfetch/config.jsonc"

    if test -f "$template_file"
        set -x DISKS_JSON "$disks_json"
        perl -0777 -pe 's/"disk",\s*"physicaldisk",/$ENV{DISKS_JSON},/g' < "$template_file" > "$config_file"
    end

    # 5. Run the actual fastfetch command
    command fastfetch $argv
end

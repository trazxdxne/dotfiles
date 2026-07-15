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

    # 3. Calculate dynamic padding for disk keys
    set -l key1 "  󱛟 $root_model (/)"
    set -l key2 ""
    if test -n "$hdd_dev"; and test -n "$hdd_model"
        set key2 "  󱛟 $hdd_model (/mnt/HDD_Linux)"
    end

    set -l len1 (string length "$key1")
    set -l len2 0
    if test -n "$key2"
        set len2 (string length "$key2")
    end

    set -l max_len $len1
    if test $len2 -gt $max_len
        set max_len $len2
    end

    set -l pad1 (math $max_len - $len1)
    set -l key1_padded "$key1"
    if test $pad1 -gt 0
        set key1_padded "$key1"(string repeat -n $pad1 " ")
    end

    set -l key2_padded ""
    if test -n "$key2"
        set key2_padded "$key2"
        set -l pad2 (math $max_len - $len2)
        if test $pad2 -gt 0
            set key2_padded "$key2"(string repeat -n $pad2 " ")
        end
    end

    # 4. Build the disk modules block (with 30 spaces padding for progress bar alignment)
    set -l disks_json "    {
      \"type\": \"disk\",
      \"folders\": \"/\",
      \"key\": \"$key1_padded\",
      \"keyColor\": \"green\",
      \"percent\": {
        \"type\": 3
      },
      \"format\": \"{size-used} / {size-total} ({size-percentage})\\n                              {size-percentage-bar}\"
    }"

    if test -n "$key2"
        set disks_json "$disks_json,
    {
      \"type\": \"disk\",
      \"folders\": \"/mnt/HDD_Linux\",
      \"key\": \"$key2_padded\",
      \"keyColor\": \"green\",
      \"percent\": {
        \"type\": 3
      },
      \"format\": \"{size-used} / {size-total} ({size-percentage})\\n                              {size-percentage-bar}\"
    }"
    end

    # 5. Generate config.jsonc from template
    set -l template_file "$HOME/.config/fastfetch/config.jsonc.template"
    set -l config_file "$HOME/.config/fastfetch/config.jsonc"

    if test -f "$template_file"
        set -x DISKS_JSON "$disks_json"
        perl -0777 -pe 's/"disk",\s*"physicaldisk",/$ENV{DISKS_JSON},/g' < "$template_file" > "$config_file"
    end

    # 6. Run the actual fastfetch command
    command fastfetch $argv
end

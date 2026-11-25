function dotpush
    set -l dot_dir ""
    for candidate in ~/.dotfiles ~/Projects/dotfiles
        if test -d "$candidate/.git"
            set dot_dir "$candidate"
            break
        end
    end
    if test -z "$dot_dir"
        echo "[-] Dotfiles repository not found in ~/.dotfiles or ~/Projects/dotfiles."
        return 1
    end

    set -l commit_msg (string join ' ' $argv)
    if test -z "$commit_msg"
        read -P ":: Commit message (Enter for auto): " commit_msg
    end

    echo ":: Checking $dot_dir status..."
    git -C "$dot_dir" add -A

    set -l changed_files (git -C "$dot_dir" diff --name-only --cached | string join ', ')
    if test -z "$changed_files"
        echo ":: Pulling latest changes..."
        git -C "$dot_dir" pull --rebase --autostash
        set -l ahead (git -C "$dot_dir" rev-list --count '@{u}..HEAD' 2>/dev/null; or echo 0)
        if test "$ahead" -gt 0
            echo ":: Pushing $ahead unpushed commit(s)..."
            git -C "$dot_dir" push
            return $status
        end
        echo "[-] No changes to commit."
        return 0
    end

    if test -z "$commit_msg"
        set -l file_count (git -C "$dot_dir" diff --name-only --cached | count)
        if test $file_count -gt 3
            set commit_msg "Update dotfiles ($file_count files)"
        else
            set commit_msg "Update $changed_files"
        end
        echo ":: Generated commit: $commit_msg"
    end

    echo ":: Creating commit..."
    if not git -C "$dot_dir" commit -m "$commit_msg"
        echo "[-] Commit failed."
        return 1
    end

    echo ":: Syncing with remote..."
    if not git -C "$dot_dir" pull --rebase --autostash
        echo "[-] Rebase failed."
        return 1
    end

    echo ":: Pushing to GitHub..."
    if not git -C "$dot_dir" push
        echo "[-] Push failed."
        return 1
    end

    echo "[+] Done."
end

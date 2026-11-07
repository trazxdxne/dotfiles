function dotpush
    set -l commit_msg (string join ' ' $argv)
    if test -z "$commit_msg"
        read -P ":: Commit message (Enter for auto): " commit_msg
    end
    
    echo ":: Getting git status..."
    git -C ~/.dotfiles add -A
    
    set -l changed_files (git -C ~/.dotfiles diff --name-only --cached | string join ', ')
    
    if test -z "$changed_files"
        echo "[-] No changes to commit."
        return 1
    end
    
    if test -z "$commit_msg"
        set -l file_count (git -C ~/.dotfiles diff --name-only --cached | count)
        if test $file_count -gt 3
            set commit_msg "Update dotfiles ($file_count files)"
        else
            set commit_msg "Update $changed_files"
        end
        echo ":: Generated commit: $commit_msg"
    end
    
    echo ":: Creating commit..."
    if not git -C ~/.dotfiles commit -m "$commit_msg"
        echo "[-] Commit failed."
        return 1
    end
    
    echo ":: Pushing to GitHub..."
    if not git -C ~/.dotfiles push
        echo "[-] Push failed."
        return 1
    end
    
    echo "[+] Done."
end

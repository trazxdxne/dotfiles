function dotpush
    set -l commit_msg $argv
    if test -z "$commit_msg"
        read -P "📝 Commit (Enter fot auto): " commit_msg
    end
    
    echo "⚙️  Get info..."
    git -C ~/dotfiles add .
    
    set -l changed_files (git -C ~/dotfiles diff --name-only --cached | string join ', ')
    
    if test -z "$changed_files"
        echo "❌ No news"
        return 1
    end
    
    if test -z "$commit_msg"
        set commit_msg "update $changed_files"
        echo "🤖 Generated commit: $commit_msg"
    end
    
    echo "📦  Creating commit..."
    git -C ~/dotfiles commit -m "$commit_msg"
    
    echo "🚀  Push to GitHub..."
    git -C ~/dotfiles push
    
    echo "✅  Done!"
end

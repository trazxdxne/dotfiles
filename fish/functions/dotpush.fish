function dotpush
    # Спрашиваем сообщение
    set -l commit_msg $argv
    if test -z "$commit_msg"
        read -P "📝 Сообщение коммита (или Enter, чтобы скрипт сам определил файлы): " commit_msg
    end
    
    echo "⚙️  Сбор измененных файлов..."
    # Сначала добавляем все изменения в память
    git -C ~/dotfiles add .
    
    # Получаем список измененных файлов через запятую
    set -l changed_files (git -C ~/dotfiles diff --name-only --cached | string join ', ')
    
    # Если изменений нет вообще - отменяем
    if test -z "$changed_files"
        echo "❌ Нет изменений для сохранения. Конфиги и так актуальны!"
        return 1
    end
    
    # Если вы нажали Enter и ничего не написали, генерируем текст коммита
    if test -z "$commit_msg"
        set commit_msg "update $changed_files"
        echo "🤖 Сгенерировано сообщение: $commit_msg"
    end
    
    echo "📦  Создание коммита..."
    git -C ~/dotfiles commit -m "$commit_msg"
    
    echo "🚀  Отправка на GitHub..."
    git -C ~/dotfiles push
    
    echo "✅  Всё готово и отправлено!"
end

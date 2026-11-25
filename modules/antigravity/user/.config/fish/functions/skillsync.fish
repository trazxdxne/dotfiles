function skillsync --description 'Track and sync mattpocock/skills, ECC, and titstack'
    if test -x ~/.local/bin/skillsync
        ~/.local/bin/skillsync $argv
    else
        python3 ~/.local/bin/skillsync $argv
    end
end

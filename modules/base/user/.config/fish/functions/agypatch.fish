function agypatch --wraps='cd ~/Projects/open-antigravity-patcher && ./patch.sh' --description 'alias agypatch=cd ~/Projects/open-antigravity-patcher && ./patch.sh'
    cd ~/Projects/open-antigravity-patcher && ./patch.sh $argv
end

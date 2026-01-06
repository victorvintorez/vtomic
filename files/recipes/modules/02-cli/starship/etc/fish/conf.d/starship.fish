function starship_transient_prompt_func
    starship prompt --profile transient
end

function starship_transient_rprompt_func
	starship module cmd_duration
end

starship init fish | source

enable_transience

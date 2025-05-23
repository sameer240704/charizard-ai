local M = {}

function M.setup()
	-- Define the syntax commands directly instead of using script-local functions
	vim.cmd([[
    augroup AIAssistSyntax
      autocmd!
      autocmd FileType ai_assist syntax match AIAssistHeader /^│.*│$/
      autocmd FileType ai_assist syntax match AIAssistBorder /[┌┐└┘─│]/
      autocmd FileType ai_assist syntax match AIAssistPrompt /^🧠.*$/
      autocmd FileType ai_assist syntax match AIAssistResponse /^🤖.*$/
      autocmd FileType ai_assist syntax match AIAssistCodeBlock /^Code block.*$/
      autocmd FileType ai_assist syntax match AIAssistContext /^📎 Context files:/
      
      autocmd FileType ai_assist_input syntax match AIAssistInputPrompt /^🧠.*$/
      
      highlight link AIAssistHeader Title
      highlight link AIAssistBorder FloatBorder
      highlight link AIAssistPrompt Special
      highlight link AIAssistResponse Identifier
      highlight link AIAssistCodeBlock Type
      highlight link AIAssistContext Comment
      highlight link AIAssistInputPrompt Special
    augroup END
    ]])
end

return M

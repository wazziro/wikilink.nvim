local M = {}

-- WikiLinkの設定オプション
M.setup = function(opts)
    -- デフォルト設定
    M.config = {
        wiki_dir = vim.fn.expand("~/org"),  -- Wikiファイルのディレクトリ
        extension = ".md",                   -- ファイルの拡張子
    }
    -- ユーザー設定をマージ
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    -- Markdownファイルでのキーマップ設定
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
            -- gfのカスタム動作を設定
            vim.keymap.set("n", "gf", function()
                local link = M.get_link_under_cursor()
                if link then
                    local filepath = M.config.wiki_dir .. "/" .. link .. M.config.extension
                    if vim.fn.filereadable(filepath) == 0 then
                        vim.cmd("edit " .. filepath)
                        vim.cmd("write")
                    else
                        vim.cmd("edit " .. filepath)
                    end
                else
                    -- 通常のgfの動作を実行
                    vim.cmd("normal! gf")
                end
            end, { buffer = true })

            -- gbでバックリンク検索
            vim.keymap.set("n", "gb", function()
                M.find_backlinks()
            end, { buffer = true, desc = "Find backlinks" })
        end
    })
end

-- カーソル位置のリンクを取得
function M.get_link_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local pattern = "%[%[(.-)%]%]"
    
    for link_start, link_end, link_text in line:gmatch("()%[%[(.-)%]%]()") do
        if col >= link_start - 1 and col <= link_end then
            return link_text
        end
    end
    return nil
end

-- バックリンク検索機能
function M.find_backlinks()
    local current_file = vim.fn.expand("%:t:r")
    local command = string.format("rg -l '\\[\\[%s\\]\\]' %s", current_file, M.config.wiki_dir)
    local results = vim.fn.systemlist(command)
    
    if #results == 0 then
        vim.notify("バックリンクが見つかりません", vim.log.levels.INFO)
        return
    end

    -- fzf-luaで結果を表示
    require("fzf-lua").fzf_exec(results, {
        prompt = "Backlinks> ",
        actions = {
            ["default"] = function(selected)
                if selected[1] then
                    vim.cmd("edit " .. selected[1])
                end
            end
        },
        previewer = "bat"  -- プレビューアを設定
    })
end

return M
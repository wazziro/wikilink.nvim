local M = {}

-- 現在のファイルが~/orgディレクトリ内かチェック
local function is_in_org_directory()
    local current_file = vim.fn.expand("%:p")  -- 絶対パス取得
    local org_dir = vim.fn.resolve(vim.fn.expand("~/org"))  -- シンボリックリンクを解決
    return current_file:find(org_dir, 1, true) == 1
end

-- tid生成関数（nokoriと同じロジック）
local function generate_tid()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local length = 5
    local result = {}
    
    -- ランダムシードを設定
    math.randomseed(os.time() + vim.fn.reltimestr(vim.fn.reltime()):gsub("[^0-9]", ""))
    
    for i = 1, length do
        local random_index = math.random(1, #charset)
        table.insert(result, charset:sub(random_index, random_index))
    end
    
    return table.concat(result)
end

-- 既存tidとの重複チェック付きtid生成
local function generate_unique_tid()
    local max_retries = 10
    local existing_tids = {}
    
    -- ~/org/tid/ディレクトリから既存tidを収集
    local tid_dir = vim.fn.expand("~/org/tid")
    if vim.fn.isdirectory(tid_dir) == 1 then
        local files = vim.fn.glob(tid_dir .. "/*.md", false, true)
        for _, file in ipairs(files) do
            local tid = vim.fn.fnamemodify(file, ":t:r")
            existing_tids[tid] = true
        end
    end
    
    -- 重複しないtidを生成
    for i = 1, max_retries do
        local tid = generate_tid()
        if not existing_tids[tid] then
            return tid
        end
    end
    
    -- フォールバック：タイムスタンプ付き
    return generate_tid() .. vim.fn.strftime("%S")
end

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
                    local tid = link.tid
                    local display_name = link.display_name
                    
                    -- tidがない場合の処理
                    if not tid and display_name then
                        -- [[|display_name]] 形式は必ずtid生成
                        tid = generate_unique_tid()
                        
                        -- 現在の行で [[|display_name]] を [[tid|display_name]] に置換
                        local line = vim.api.nvim_get_current_line()
                        -- 特殊文字をエスケープ
                        local escaped_name = display_name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
                        local new_line = line:gsub("%[%[|" .. escaped_name .. "%]%]", "[[" .. tid .. "|" .. display_name .. "]]")
                        vim.api.nvim_set_current_line(new_line)
                        
                        vim.notify("Generated new tid: " .. tid, vim.log.levels.INFO)
                    elseif tid and not display_name then
                        -- [[task_name]] 形式の場合（tidフィールドにはtask_nameが入ってる）
                        local task_name = tid
                        
                        -- ~/org内かつファイルが存在しない場合はtid生成
                        if is_in_org_directory() then
                            local potential_file = vim.fn.expand(M.config.wiki_dir) .. "/" .. task_name .. M.config.extension
                            if vim.fn.filereadable(potential_file) == 0 then
                                -- ファイルが存在しないのでtid生成
                                tid = generate_unique_tid()
                                display_name = task_name
                                
                                -- 現在の行で [[task_name]] を [[tid|task_name]] に置換
                                local line = vim.api.nvim_get_current_line()
                                local escaped_name = task_name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
                                local new_line = line:gsub("%[%[" .. escaped_name .. "%]%]", "[[" .. tid .. "|" .. task_name .. "]]")
                                vim.api.nvim_set_current_line(new_line)
                                
                                vim.notify("Generated new tid: " .. tid .. " for: " .. task_name, vim.log.levels.INFO)
                            else
                                -- ファイルが存在するので既存動作
                                vim.cmd("edit " .. potential_file)
                                return
                            end
                        else
                            -- ~/org外は既存動作（tidをそのまま使用）
                            -- tidをリセットしないで、下の処理で既存動作
                        end
                    end
                    
                    -- tidがある場合のみファイルを開く
                    if tid then
                        local filepath = vim.fn.expand(M.config.wiki_dir) .. "/tid/" .. tid .. M.config.extension
                        
                        -- ファイルが存在しない場合は新規作成
                        if vim.fn.filereadable(filepath) == 0 then
                            -- 親ディレクトリを再帰的に作成
                            local parent_dir = vim.fn.fnamemodify(filepath, ":h")
                            if vim.fn.isdirectory(parent_dir) == 0 then
                                vim.fn.mkdir(parent_dir, "p")
                            end
                            
                            -- ファイルを開く
                            vim.cmd("edit " .. vim.fn.fnameescape(filepath))
                            
                            -- 表示名がある場合はタイトルを自動挿入
                            if display_name then
                                local lines = { "# " .. display_name }
                                vim.api.nvim_buf_set_lines(0, 0, 0, false, lines)
                            end
                            
                            -- ファイル保存
                            vim.cmd("write")
                        else
                            vim.cmd("edit " .. filepath)
                        end
                    end
                else
                    -- カーソル位置のファイルパスを取得して開く
                    local filepath = vim.fn.expand("<cfile>")
                    if filepath ~= "" then
                        vim.cmd("edit " .. filepath)
                    end
                end
            end, { buffer = true })

            -- gbでバックリンク検索
            vim.keymap.set("n", "gb", function()
                M.find_backlinks()
            end, { buffer = true, desc = "Find backlinks" })
        end
    })
    
    -- tidファイルで特別なキーマップを設定
    local function setup_tid_keymaps()
        -- tidディレクトリ内のファイルかチェック
        if vim.fn.expand("%:h"):match("/tid$") then
            -- <Leader>b で前のバッファに戻る
            vim.keymap.set("n", "<Leader>b", "<C-^>", { buffer = true, desc = "Back to previous buffer" })
            
            -- :wq の代わりに :Wq コマンドを作成（保存して前のバッファに戻る）
            vim.api.nvim_buf_create_user_command(0, 'Wq', function()
                vim.cmd('write')
                vim.cmd('buffer #')  -- 前のバッファに戻る
            end, { desc = "Write and go back to previous buffer" })
        end
    end
    
    -- ファイル読み込み時にtidキーマップを設定
    vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
        pattern = "*/tid/*.md",
        callback = setup_tid_keymaps
    })
end

-- カーソル位置のリンクを取得
-- Returns: { tid = "F99DD", display_name = "表示名" } or nil
function M.get_link_under_cursor()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-basedに変換
    
    local start_pos = 1
    local closest_link = nil
    local min_distance = math.huge
    
    while true do
        local link_start, link_end, link_content = line:find("%[%[(.-)%]%]", start_pos)
        if not link_start then break end
        
        -- カーソルがリンク内にあるかチェック
        if col >= link_start and col <= link_end then
            -- [[tid|display_name]] 形式をパース
            local tid, display_name = link_content:match("^([^|]+)|(.+)$")
            if tid and display_name then
                return { tid = tid, display_name = display_name }
            elseif link_content:match("^|(.+)$") then
                -- [[|display_name]] 形式（tidなし）
                local display_only = link_content:match("^|(.+)$")
                return { tid = nil, display_name = display_only }
            else
                -- パイプなしの場合は既存の動作
                return { tid = link_content, display_name = nil }
            end
        end
        
        -- カーソルに最も近いリンクを記録
        local distance = math.min(math.abs(col - link_start), math.abs(col - link_end))
        if distance < min_distance then
            min_distance = distance
            local tid, display_name = link_content:match("^([^|]+)|(.+)$")
            if tid and display_name then
                closest_link = { tid = tid, display_name = display_name }
            elseif link_content:match("^|(.+)$") then
                -- [[|display_name]] 形式（tidなし）
                local display_only = link_content:match("^|(.+)$")
                closest_link = { tid = nil, display_name = display_only }
            else
                closest_link = { tid = link_content, display_name = nil }
            end
        end
        
        start_pos = link_end + 1
    end
    
    return closest_link
end

-- バックリンク検索機能
function M.find_backlinks()
    local current_file = vim.fn.expand("%:t:r")
    
    -- tidファイルの場合はtidで検索、そうでなければファイル名で検索
    local search_pattern
    if vim.fn.expand("%:h"):match("/tid$") then
        -- tidファイルの場合は [[tid| で検索
        search_pattern = string.format("\\[\\[%s\\|", current_file)
    else
        -- 既存の動作：ファイル名で検索
        search_pattern = string.format("\\[\\[%s\\]\\]", current_file)
    end
    
    local command = string.format("rg -l '%s' %s", search_pattern, vim.fn.expand(M.config.wiki_dir))
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
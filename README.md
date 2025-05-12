# wikilink.nvim

Neovimプラグイン for Wikiスタイルのリンクナビゲーション

## 機能

- `[[リンク名]]`形式のWikiリンクをサポート
- `gf`でリンク先のファイルを開く/作成
- `gb`でバックリンクをfzf-luaで検索

## 必要条件

- Neovim >= 0.5.0
- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [ripgrep](https://github.com/BurntSushi/ripgrep)

## インストール

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "あなたのGitHubユーザー名/wikilink.nvim",
    config = function()
        require("wikilink").setup({
            wiki_dir = "~/org",    -- Wikiディレクトリ
            extension = ".md"      -- ファイルの拡張子
        })
    end,
    dependencies = {
        "ibhagwan/fzf-lua"
    }
}
```

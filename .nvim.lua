local group = vim.api.nvim_create_augroup("prettier_on_save", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = { "*.ts", "*.json", "*.yaml", "*.yml", "*.md" },
    callback = function(args)
        local bufnr = args.buf
        local path = vim.api.nvim_buf_get_name(bufnr)

        if path == "" then
            return;
        end

        local stdout_data
        local stderr_data

        vim.fn.jobstart({ "pnpm", "exec", "prettier", "--write", path, }, {
            cwd = vim.fs.root(path, { "package.json" }),
            -- cwd = vim.fn.fnamemodify(path, ":h"),
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function (_, data)
                stdout_data = data
            end,
            on_stderr = function (_, data)
                stderr_data = data
            end,
            on_exit = function(_, code)
                vim.schedule(function()
                    if code == 0 then
                        if vim.api.nvim_buf_is_loaded(bufnr) and not vim.bo[bufnr].modified then
                            vim.api.nvim_buf_call(bufnr, function()
                                vim.cmd("checktime")
                            end)
                        end
                    else
                        local output = table.concat(vim.list_extend(stdout_data, stderr_data), "\n")
                        vim.notify("'pnpm exec prettier --write " .. path .. "' exited with code " .. code .. "\n" .. output, vim.log.levels.ERROR)
                    end
                end)
            end
        })
    end
})

-- update-lockfile.lua
--
-- Usage:
--   nvim --headless -u NONE -n -l update-lockfile.lua
--
-- Made with assistance from ChatGPT

local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = vim.fn.fnamemodify(script_path, ":p:h")

package.path = script_dir .. "/vendor/?.lua;" .. package.path

local dkjson = require("dkjson")

local function nix_store_dir()
	local lines = vim.fn.systemlist({
		"nix",
		"eval",
		"--raw",
		"--expr",
		"builtins.storeDir",
	})

	if vim.v.shell_error ~= 0 then
		error("failed to get Nix store dir:\n" .. table.concat(lines, "\n"))
	end

	return lines[#lines]
end

local function nix_build_out_path(installable)
	local store_dir = nix_store_dir()

	local lines = vim.fn.systemlist({
		"nix",
		"build",
		"--no-link",
		"--print-out-paths",
		"--no-warn-dirty",
		installable,
	})

	if vim.v.shell_error ~= 0 then
		error("nix build failed:\n" .. table.concat(lines, "\n"))
	end

	local paths = {}

	for _, line in ipairs(lines) do
		if vim.startswith(line, store_dir .. "/") then
			table.insert(paths, line)
		end
	end

	if #paths ~= 1 then
		error("expected exactly one store output path, got:\n" .. table.concat(lines, "\n"))
	end

	return paths[1]
end

local repos_path = nix_build_out_path(".#tree-sitter-manager-nvim-src.out") .. "/lua/tree-sitter-manager/repos.lua"

local chunk = assert(loadfile(repos_path))
local repos = chunk()

local old_lock = {}

if vim.fn.filereadable("tree-sitter-manager-grammars.lock.json") == 1 then
	old_lock = vim.json.decode(table.concat(vim.fn.readfile("tree-sitter-manager-grammars.lock.json"), "\n"))
end

local lock = {}

local function copy_field(dst, src, key)
	if src[key] ~= nil then
		dst[key] = src[key]
	end
end

local function spawn_collect(cmd, args, on_done)
	local stdout = vim.uv.new_pipe(false)
	assert(stdout ~= nil)
	local stderr = vim.uv.new_pipe(false)
	assert(stderr ~= nil)

	local stdout_chunks = {}
	local stderr_chunks = {}

	local handle
	handle = vim.uv.spawn(cmd, {
		args = args,
		stdio = { nil, stdout, stderr },
	}, function(code, signal)
		stdout:read_stop()
		stderr:read_stop()
		stdout:close()
		stderr:close()

		if handle and not handle:is_closing() then
			handle:close()
		end

		vim.schedule(function()
			on_done({
				code = code,
				signal = signal,
				stdout = table.concat(stdout_chunks),
				stderr = table.concat(stderr_chunks),
			})
		end)
	end)

	if not handle then
		stdout:close()
		stderr:close()

		vim.schedule(function()
			on_done({
				code = 127,
				signal = 0,
				stdout = "",
				stderr = "failed to spawn " .. cmd,
			})
		end)

		return
	end

	stdout:read_start(function(err, data)
		if err then
			table.insert(stderr_chunks, err)
		elseif data then
			table.insert(stdout_chunks, data)
		end
	end)

	stderr:read_start(function(err, data)
		if err then
			table.insert(stderr_chunks, err)
		elseif data then
			table.insert(stderr_chunks, data)
		end
	end)
end

local function prefetch_all(items, max_jobs)
	max_jobs = max_jobs or 8

	local queue = {}
	for lang, item in pairs(items) do
		table.insert(queue, {
			lang = lang,
			item = item,
		})
	end

	table.sort(queue, function(a, b)
		return a.lang < b.lang
	end)

	local results = {}
	local errors = {}

	local next_index = 1
	local running = 0
	local done = 0
	local total = #queue

	local function start_more()
		while running < max_jobs and next_index <= total do
			local entry = queue[next_index]
			next_index = next_index + 1
			running = running + 1

			local lang = entry.lang
			local item = entry.item

			if item.query_only then
				running = running - 1
				done = done + 1
				start_more()
			else
				local args = {
					"--url",
					item.url,
					"--rev",
					item.revision,
				}

				spawn_collect("nix-prefetch-git", args, function(res)
					running = running - 1
					done = done + 1

					if res.code ~= 0 then
						errors[lang] = {
							message = "nix-prefetch-git failed",
							code = res.code,
							stderr = res.stderr,
						}
					else
						local ok, decoded = pcall(vim.json.decode, res.stdout)

						if ok then
							results[lang] = decoded
						else
							errors[lang] = {
								message = "failed to parse nix-prefetch-git JSON",
								stdout = res.stdout,
								stderr = res.stderr,
							}
						end
					end

					print(("finished %s (%d/%d)"):format(lang, done, total))

					-- Start the next queued jobs now that a slot opened.
					start_more()
				end)
			end
		end
	end

	start_more()

	-- Keep headless nvim alive until every job has completed.
	vim.wait(1000 * 60 * 60, function()
		return done == total
	end, 100)

	return results, errors
end

for lang, spec in pairs(repos) do
	local install_info = spec.install_info or spec

	local item = {}

	copy_field(item, install_info, "url")
	copy_field(item, install_info, "revision")
	copy_field(item, install_info, "branch")
	copy_field(item, install_info, "location")
	copy_field(item, install_info, "queries")
	copy_field(item, install_info, "generate")
	copy_field(item, install_info, "use_repo_queries")

	copy_field(item, spec, "requires")
	copy_field(item, spec, "filetype")

	-- Query-only entries have no parser repo. (e.g. ecma, jsx)
	if item.url == nil then
		item.query_only = true
	else
		item.query_only = false
	end

	if old_lock[lang] then
		copy_field(item, old_lock[lang], "hash")
	end

	lock[lang] = item
end

local lock_filtered = {}

for lang, spec in pairs(lock) do
	local old = old_lock[lang]

	if not spec.query_only and not (old and old.revision == spec.revision and old.hash) then
		lock_filtered[lang] = spec
	end
end

local prefetched = prefetch_all(lock_filtered)

for lang, prefetch_out in pairs(prefetched) do
	lock[lang].hash = prefetch_out.hash
end

local language_order = {}

for lang, _ in pairs(lock) do
	table.insert(language_order, lang)
end

table.sort(language_order)

setmetatable(lock, {
	__jsonorder = language_order,
})

local encoded = dkjson.encode(lock, {
	indent = true,
	keyorder = {
		"url",
		"revision",
		"hash",
		"location",
		"generate",
		"queries",
		"use_repo_queries",
		"query_only",
		"readme_note",
	},
}) .. "\n"

assert(vim.uv.fs_write(assert(vim.uv.fs_open("tree-sitter-manager-grammars.lock.json", "w", 420)), encoded))

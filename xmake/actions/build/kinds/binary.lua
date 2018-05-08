--!A cross-platform build utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2018, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        binary.lua
--

-- imports
import("core.base.option")
import("core.tool.linker")
import("core.tool.compiler")
import("core.project.depend")
import("object")

-- build target from sources
function _build_from_objects(target, buildinfo)

    -- build objects
    object.build(target, buildinfo)

    -- load linker instance
    local linker_instance = linker.load(target:targetkind(), target:sourcekinds(), {target = target})

    -- get link flags
    local linkflags = linker_instance:linkflags({target = target})

    -- load dependent info 
    local dependinfo = {}
    local dependfile = target:dependfile()
    if not buildinfo.rebuild then
        dependinfo = depend.load(dependfile) or {}
    end

    -- need build this target?
    local depvalues = {linker_instance:program(), linkflags}
    if not buildinfo.rebuild and not depend.is_changed(dependinfo, {lastmtime = os.mtime(target:targetfile()), values = depvalues}) then
        return 
    end

    -- expand object files with *.o/obj
    local objectfiles = {}
    for _, objectfile in ipairs(target:objectfiles()) do
        if objectfile:find("%*") then
            local matchfiles = os.match(objectfile)
            if matchfiles then
                table.join2(objectfiles, matchfiles)
            end
        else
            table.insert(objectfiles, objectfile)
        end
    end

    -- the target file
    local targetfile = target:targetfile()

    -- is verbose?
    local verbose = option.get("verbose")

    -- trace percent into
    cprintf("${green}[%02d%%]:${clear} ", (buildinfo.targetindex + 1) * 100 / buildinfo.targetcount)
    if verbose then
        cprint("${dim magenta}linking.$(mode) %s", path.filename(targetfile))
    else
        cprint("${magenta}linking.$(mode) %s", path.filename(targetfile))
    end

    -- trace verbose info
    if verbose then
        print(linker_instance:linkcmd(objectfiles, targetfile, {linkflags = linkflags}))
    end

    -- flush io buffer to update progress info
    io.flush()

    -- link it
    assert(linker_instance:link(objectfiles, targetfile, {linkflags = linkflags}))

    -- update files and values to the dependent file
    dependinfo.values = depvalues
    dependinfo.files  = target:objectfiles()
    for _, dep in pairs(target:deps()) do
        if dep:targetkind() == "static" then
            table.insert(dependinfo.files, dep:targetfile())
        end
    end
    depend.save(dependinfo, dependfile)
end

-- build target from sources
function _build_from_sources(target, buildinfo, sourcebatch, sourcekind)

    -- the target file
    local targetfile = target:targetfile()

    -- is verbose?
    local verbose = option.get("verbose")

    -- trace percent into
    cprintf("${green}[%02d%%]:${clear} ", (buildinfo.targetindex + 1) * 100 / buildinfo.targetcount)
    if verbose then
        cprint("${dim magenta}linking.$(mode) %s", path.filename(targetfile))
    else
        cprint("${magenta}linking.$(mode) %s", path.filename(targetfile))
    end

    -- trace verbose info
    if verbose then
        print(compiler.buildcmd(sourcebatch.sourcefiles, targetfile, {target = target, sourcekind = sourcekind}))
    end

    -- flush io buffer to update progress info
    io.flush()

    -- build it
    compiler.build(sourcebatch.sourcefiles, targetfile, {target = target, sourcekind = sourcekind})
end

-- build binary target
function build(target, buildinfo)

    -- only one source kind?
    local kindcount = 0
    local sourcekind = nil
    local sourcebatch = nil
    for kind, batch in pairs(target:sourcebatches()) do
        sourcekind  = kind
        sourcebatch = batch
        kindcount   = kindcount + 1
        if kindcount > 1 then
            break
        end
    end

    -- build target
    if kindcount == 1 and sourcekind and not sourcekind:startswith("__rule_") and compiler.buildmode(sourcekind, "binary:sources", {target = target}) then
        _build_from_sources(target, buildinfo, sourcebatch, sourcekind)
    else
        _build_from_objects(target, buildinfo)
    end
end

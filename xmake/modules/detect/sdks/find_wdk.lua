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
-- @file        find_wdk.lua
--

-- imports
import("lib.detect.cache")
import("lib.detect.find_file")
import("core.base.option")
import("core.base.global")
import("core.project.config")

-- find WDK directory
function _find_sdkdir(sdkdir)

    -- get sdk directory from vsvars
    if not sdkdir then
        local arch = config.arch()
        local vcvarsall = config.get("__vcvarsall")
        if vcvarsall then
            sdkdir = (vcvarsall[arch] or {}).WindowsSdkDir
        end
    end
    return sdkdir
end

-- find WDK toolchains
function _find_wdk(sdkdir, sdkver)

    -- find wdk directory
    sdkdir = _find_sdkdir(sdkdir)
    if not sdkdir or not os.isdir(sdkdir) then
        return nil
    end

    -- get sdk version
    if not sdkver then
        local vers = {}
        for _, dir in ipairs(os.dirs(path.join(sdkdir, "Include", "**", "km"))) do
            table.insert(vers, path.filename(path.directory(dir)))
        end
        for _, ver in ipairs(vers) do
            if os.isdir(path.join(sdkdir, "Lib", ver, "km")) and os.isdir(path.join(sdkdir, "Lib", ver, "um")) and os.isdir(path.join(sdkdir, "Include", ver, "um"))  then
                sdkver = ver
                break
            end
        end
    end
    if not sdkver then
        return nil
    end

    -- get the bin directory 
    local bindir = path.join(sdkdir, "bin")

    -- get the lib directory
    local libdir = path.join(sdkdir, "Lib")

    -- get the include directory
    local includedir = path.join(sdkdir, "Include")

    -- get toolchains
    return {sdkdir = sdkdir, bindir = bindir, libdir = libdir, includedir = includedir, sdkver = sdkver}
end

-- find WDK toolchains
--
-- @param sdkdir    the WDK directory
-- @param opt       the argument options, .e.g {verbose = true, force = false, version = "5.9.1"} 
--
-- @return          the WDK toolchains. .e.g {sdkver = ..., sdkdir = ..., bindir = .., libdir = ..., includedir = ..., .. }
--
-- @code 
--
-- local toolchains = find_wdk("~/wdk")
-- 
-- @endcode
--
function main(sdkdir, opt)

    -- init arguments
    opt = opt or {}

    -- attempt to load cache first
    local key = "detect.sdks.find_wdk." .. (sdkdir or "")
    local cacheinfo = cache.load(key)
    if not opt.force and cacheinfo.wdk then
        return cacheinfo.wdk
    end
       
    -- find wdk
    local wdk = _find_wdk(sdkdir or config.get("wdk") or global.get("wdk"), opt.version or config.get("wdk_sdkver"))
    if wdk then

        -- save to config
        config.set("wdk", wdk.sdkdir, {force = true, readonly = true})
        config.set("wdk_sdkver", wdk.sdkver, {force = true, readonly = true})

        -- trace
        if opt.verbose or option.get("verbose") then
            cprint("checking for the WDK directory ... ${green}%s", wdk.sdkdir)
            cprint("checking for the WDK version ... ${green}%s", wdk.sdkver)
        end
    else

        -- trace
        if opt.verbose or option.get("verbose") then
            cprint("checking for the WDK directory ... ${red}no")
        end
    end

    -- save to cache
    cacheinfo.wdk = wdk or false
    cache.save(key, cacheinfo)

    -- ok?
    return wdk
end

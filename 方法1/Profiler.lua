-- 代码性能监控
local Profiler = {}--class("Profiler")

local filePath = "d:/Profiler.txt"
-- start profiling

function Profiler:Init()
end

function Profiler:Start()
  -- 初始化报告
  self._REPORTS           = {}
  self._REPORTS_BY_TITLE  = {}
  -- 记录开始时间
  self._STARTIME = os.clock()
  -- 开始hook，注册handler，记录call和return事件
  debug.sethook(Profiler._ProfilingHandler, 'cr', 0)
end

-- stop profiling
function Profiler:Stop()
  -- 记录结束时间
  self._STOPTIME = os.clock()
  -- 停止hook
  debug.sethook()
  -- 记录总耗时
  local total_time = self._STOPTIME - self._STARTIME
  -- 排序报告
  table.sort(self._REPORTS, function(a, b)
    return a.total_time > b.total_time
  end)
  local content = ""
  -- 格式化报告输出
  local head = string.format("%s, %s, %s, %s, %s, %s, %s",
          "总时",
          "     占比",
          "调用次数",
          "平均用时",
          "最大用时",
          "最小用时",
          "函数名")
  content = content .. head .. "\n"
  for _, report in ipairs(self._REPORTS) do
    -- calculate percent
    while true do
      local percent = (report.total_time / total_time) * 100
      if percent < 1 then
        break
      end
      -- trace
      if not report.max_time then break end
      local row = string.format("%6.4f, %6.2f%%,  %7d,   %6.4f,   %6.4f    %6.4f   %s",
              report.total_time,
              percent,
              report.call_count,
              report.total_time / report.call_count,
              report.max_time,
              report.min_time,
              report.title)
      content = content .. row .. "\n"
      break
    end
  end

  local mode ="w"
  local file = io.open(filePath, mode)
  file:write(content)
  file:close()
  os.execute("explorer file:" .. filePath)
  return self._REPORTS
end

-- profiling call
function Profiler:_ProfilingCall(funcinfo)
  -- 获取当前函数对应的报告，如果不存在则初始化下
  local report = self:_FuncReport(funcinfo)
  assert(report)
  -- 记录这个函数的起始调用事件
  report.call_time    = os.clock()
  -- 累加这个函数的调用次数
  report.call_count   = report.call_count + 1
end

-- profiling return
function Profiler:_ProfilingReturn(funcinfo)
  -- 记录这个函数的返回时间
  local stoptime = os.clock()
  -- 获取当前函数的报告
  local report = self:_FuncReport(funcinfo)
  assert(report)
  -- 计算和累加当前函数的调用总时间
  if report.call_time and report.call_time > 0 then
    local pass_time = stoptime - report.call_time
    report.total_time = report.total_time + pass_time
    report.max_time = report.max_time and math.max(report.max_time, pass_time) or pass_time
    report.min_time = report.min_time and math.min(report.min_time, pass_time) or pass_time
    report.call_time = 0
  end
end

-- the profiling handler
function Profiler._ProfilingHandler(hooktype)
  -- 获取当前函数信息
  local funcinfo = debug.getinfo(2, 'nS')
  -- 根据事件类型，分别处理 
  if hooktype == "call" then
    Profiler:_ProfilingCall(funcinfo)
  elseif hooktype == "return" then
    Profiler:_ProfilingReturn(funcinfo)
  end
end

-- get the function title
function Profiler:_FuncTitle(funcinfo)
  -- check
  assert(funcinfo)
  -- the function name
  local name = funcinfo.name or 'anonymous'
  -- the function line
  local line = string.format("%d", funcinfo.linedefined or 0)
  -- the function source
  local source = funcinfo.short_src or 'C_FUNC'
--  if os.isfile(source) then
--    source = path.relative(source, xmake._PROGRAM_DIR)
--  end
  -- make title
  return string.format("%-30s: %s: %s", name, source, line)
end

-- get the function report
function Profiler:_FuncReport(funcinfo)
  -- get the function title
  local title = self:_FuncTitle(funcinfo)
  -- get the function report
  local report = self._REPORTS_BY_TITLE[title]
  if not report then
      -- init report
      report = {
        title       = self:_FuncTitle(funcinfo),
        call_count   = 0,
        total_time   = 0
      }
      -- save it
      self._REPORTS_BY_TITLE[title] = report
      table.insert(self._REPORTS, report)
  end
  -- ok?
  return report
end

--Test
--if profiler then
--  profiler:Stop()
--  profiler = nil
--end

--profiler = require("Profiler")
--profiler:Start()

return Profiler
--endregion

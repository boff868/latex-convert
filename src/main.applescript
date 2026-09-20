-- ============================================================
--  「LaTeX 转换」的 AppleScript 前端（droplet）
--
--  双击图标：显示用法说明
--  拖入 .tex 文件 / 文件夹：弹出选择框，选 PDF 或 Word，
--  然后把文件路径交给 App 内置的 convert.sh 完成转换。
-- ============================================================

on run
	display dialog "用法：把一个或多个 .tex 文件（或包含 .tex 的文件夹）拖到本应用图标上，松手后选择转换格式。

· Word —— 用 pandoc 生成 .docx
· PDF  —— 用本地 LaTeX 引擎编译 .pdf

输出文件会生成在源 .tex 文件的同一目录。" buttons {"好的"} default button "好的" with title "LaTeX 转换" with icon note
end run

on open theItems
	-- 1) 把拖入的 Finder 对象统一转成 POSIX 路径
	set pathList to {}
	repeat with i in theItems
		set end of pathList to POSIX path of i
	end repeat

	-- 2) 让用户选择转换格式
	set dlg to display dialog ("共 " & (count of pathList) & " 个文件，转成：") buttons {"取消", "PDF", "Word"} default button "Word" with title "LaTeX 转换"
	set btn to button returned of dlg
	if btn is "取消" then return
	if btn is "Word" then
		set fmt to "word"
	else
		set fmt to "pdf"
	end if

	-- 3) 拼出命令行的参数串（路径一律 quoted form 防空格）
	set argStr to ""
	repeat with p in pathList
		set argStr to argStr & " " & quoted form of p
	end repeat

	-- 4) 定位本 App 包内的转换引擎 convert.sh
	set myPath to POSIX path of (path to me)
	if myPath ends with "/" then
		set shPath to myPath & "Contents/Resources/convert.sh"
	else
		set shPath to myPath & "/Contents/Resources/convert.sh"
	end if
	set sh to quoted form of shPath

	-- 5) 调用引擎（超时放宽到 1 小时，便于大文档编译）
	try
		with timeout of 3600 seconds
			set res to do shell script sh & " " & fmt & argStr
		end timeout
		display dialog res buttons {"好的"} default button "好的" with title "LaTeX 转换" with icon note
	on error errMsg
		display dialog errMsg buttons {"好的"} default button "好的" with title "LaTeX 转换" with icon stop
	end try
end open

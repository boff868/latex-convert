-- ============================================================
--  「LaTeX 转换 / 阅览」的 AppleScript 前端（droplet）
--
--  双击图标：显示用法说明
--  拖入 .tex 文件 / 文件夹：弹出选择框，选 预览 / PDF / Word，
--  然后把文件路径交给 App 内置的脚本完成对应操作。
--    预览 —— preview.sh：在浏览器里打开「排版预览 + 源码」阅读页
--    Word —— convert.sh word：pandoc 生成 .docx
--    PDF  —— convert.sh pdf ：本地 LaTeX 引擎编译 .pdf
-- ============================================================

on run
	display dialog "用法：把一个或多个 .tex 文件（或包含 .tex 的文件夹）拖到本应用图标上，松手后选择操作。

· 预览 —— 在浏览器中打开阅读页：可切换「排版预览 / 源码」两个视图
· Word —— 用 pandoc 生成 .docx
· PDF  —— 用本地 LaTeX 引擎编译 .pdf

转换结果会生成在源 .tex 文件的同一目录。" buttons {"好的"} default button "好的" with title "LaTeX 转换" with icon note
end run

on open theItems
	-- 1) 把拖入的 Finder 对象统一转成 POSIX 路径
	set pathList to {}
	repeat with i in theItems
		set end of pathList to POSIX path of i
	end repeat

	-- 2) 拼出命令行参数串（路径一律 quoted form，防空格/中文出错）
	set argStr to ""
	repeat with p in pathList
		set argStr to argStr & " " & quoted form of p
	end repeat

	-- 3) 定位本 App 包内的脚本目录
	set myPath to POSIX path of (path to me)
	if myPath ends with "/" then
		set resPath to myPath & "Contents/Resources/"
	else
		set resPath to myPath & "/Contents/Resources/"
	end if

	-- 4) 选择操作（display dialog 最多 3 个按钮，Esc 即取消）
	try
		set dlg to display dialog ("共 " & (count of pathList) & " 个文件，请选择操作：") buttons {"预览", "PDF", "Word"} default button "Word" with title "LaTeX 转换" with icon note
	on error number -128
		return
	end try
	set btn to button returned of dlg

	if btn is "预览" then
		set cmd to "bash " & quoted form of (resPath & "preview.sh") & argStr
	else if btn is "Word" then
		set cmd to "bash " & quoted form of (resPath & "convert.sh") & " word" & argStr
	else
		set cmd to "bash " & quoted form of (resPath & "convert.sh") & " pdf" & argStr
	end if

	-- 5) 执行并把结果回显（超时放宽到 1 小时，便于大文档编译）
	try
		with timeout of 3600 seconds
			set res to do shell script cmd
		end timeout
		display dialog res buttons {"好的"} default button "好的" with title "LaTeX 转换" with icon note
	on error errMsg
		display dialog errMsg buttons {"好的"} default button "好的" with title "LaTeX 转换" with icon stop
	end try
end open

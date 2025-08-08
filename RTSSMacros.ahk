#NoEnv
#SingleInstance Force
#Persistent
#Include RTSSReader.ahk
global runningGTA := processExist("GTA5_Enhanced.exe") ? "GTA5_Enhanced.exe" : "GTA5.exe"
#If WinActive("ahk_exe " runningGTA)

    SetBatchLines, -1
    SetKeyDelay, -1, -1
    SetMouseDelay, -1
    SetWinDelay, -1
    SetControlDelay, -1
    ListLines Off
    SendMode Input

    Process, Priority, , High
    Process, Priority, GTA5.exe, High

    DllCall("ntdll\ZwSetTimerResolution","Int",5000,"Int",1,"Int*",MyCurrentTimerResolution)
    try {
        global RTSSListener := new RTSSReader(runningGTA)
    } catch e {
        MsgBox, 16, Error, % "Failed to initialize RTSS reader.`n`n" e.Message
        ExitApp
    }

    global inputHandler = new InputManager(1, 1, 10) ; Configure extra delay on top of framerate-based delay, and minimum delay allowed (it'll default to this delay if your frametimes are lower than this value)

    Hotkey, *§, BST
    Hotkey, *F2, Ammo

    ; SetTimer, thing, 100
    return

    thing:
        Tooltip, % RTSSListener.getFrameTime() " size " RTSSListener.frametimes.Length(), -1000, -1000
    Return

    BST: ; Example macros that I made for testing this shit
        InputManager.sendInputs(["m","enter","down 4","enter","down","enter"])
    Return

    Ammo:
        InputManager.sendInputs(["m","down 4","enter 2","sleep 4","right","up","enter","m"])
    Return

    class InputManager {
        static inputSanitizerPattern := "O)(\w+)\s?(down|up|\d+)?"
        static numberCheckPattern = "^\d+$"

        delay := 0
        pressDuration := 0
        minimumDelay := 0

        __New(delay, pressDuration, minimumDelay) {
            this.delay := delay
            this.pressDuration := pressDuration
            this.minimumDelay := minimumDelay
        }

        ; The Parameter is an array of keys; doesn't support raw strings cause I was lazy and that is a lot of effort for no gain. You can also type in "sleep" to wait for appromximately 1 frame, or sleep multiple times.
        sendInputs(inputs) {
            if (RTSSListener.measuringFrametime) {
                sanitizedInputs := this._sanitizeInputs(inputs)
                sentStr := []
                for index, input in sanitizedInputs {
                    if (input.sleep) {
                        sentStr.Push("sleep")
                        Sleep(Max(RTSSListener.getFrameTime() + inputHandler.delay, 1000 / (RTSSListener.getFPS() * 0.8), inputHandler.minimumDelay)) ; Why the fuck are this variables undefined and I have to reference inputHandler?
                    } else if (input.single) {
                        Send % "{Blind}" . input.rawInput
                        sentStr.Push("{Blind}" . input.rawInput)
                    } else {
                        Send % "{Blind}" input.rawInput . " down}"
                        sentStr.Push("{Blind}" input.rawInput . " down}")
                        Sleep(Max(RTSSListener.getFrameTime() + inputHandler.pressDuration, 1000 / (RTSSListener.getFPS() * 0.8), inputHandler.minimumDelay))
                        Send % "{Blind}" input.rawInput . " up}"
                        sentStr.Push("{Blind}" input.rawInput . " up}")
                        Sleep(Max(RTSSListener.getFrameTime() + inputHandler.delay, 1000 / (RTSSListener.getFPS() * 0.8), inputHandler.minimumDelay))
                    }
                }
            }
        }

        _sanitizeInputs(inputs) {
            sanitizedData := []
            for index, input in inputs {
                if (RegExMatch(input, this.inputSanitizerPattern, inputMatch)) {
                    inputName := inputMatch[1]
                    secondArgMatch := inputMatch[2]

                    sanitizedInput := {}
                    if (inputName = "sleep") {
                        sanitizedInput.sleep := true
                    } else if (secondArgMatch == "" || this._isNumber(secondArgMatch)) {
                        sanitizedInput.rawInput := "{" inputName
                        sanitizedInput.single := false
                        sanitizedInput.sleep := false
                    } else {
                        sanitizedInput.rawInput := "{" inputMatch[0] "}"
                        sanitizedInput.single := true
                        sanitizedInput.sleep := false
                    }
                    amount := this._isNumber(secondArgMatch) ? secondArgMatch : 1
                    Loop %amount% {
                        sanitizedData.Push(sanitizedInput)
                    }
                }
            }
            return sanitizedData
        }

        _isNumber(str) {
            return RegExMatch(str, this.numberCheckPattern)
        }
    }

    Sleep(ms)
    {
        DllCall("QueryPerformanceFrequency", "Int64*", freq)
        DllCall("QueryPerformanceCounter", "Int64*", CounterBefore)

        While (((counterAfter - CounterBefore) / freq * 1000) < ms) {
            RTSSListener._updateFrameTimes()
            DllCall("QueryPerformanceCounter", "Int64*", CounterAfter)
        }

        RTSSListener._updateFrameTimes()
        return ((counterAfter - CounterBefore) / freq * 1000)
    }

    StartCounting() {
        DllCall("QueryPerformanceFrequency", "Int64*", frequency)
        DllCall("QueryPerformanceCounter", "Int64*", CounterBefore)
        return CounterBefore / frequency
    }

    stopCounting(startTime) {
        DllCall("QueryPerformanceFrequency", "Int64*", frequency)
        DllCall("QueryPerformanceCounter", "Int64*", CounterAfter)
        return (CounterAfter / frequency - startTime) * 1000
    }

    processExist(name) {
        Process, Exist, %name%
        return ErrorLevel
    }
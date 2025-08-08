class RTSSReader {
    ; rtss memory offset for fps
    static fpsMemoryOffset := 276
    static frametimeMemoryOffset := 280

    hMapFile := 0
    pMapAddr := 0
    processEntryAddress := 0
    targetProcess := ""
    measuringFrametime := false
    frametimes := []
    averagingInterval := 500
    averageFrametime := 0
    originTime := 0
    timeFrequency := 0

    __New(targetProcess) {
        this.targetProcess := targetProcess
        if (!processExist(this.targetProcess)) {
            throw Exception("Target process doesn't exist")
        }

        fileMapRead := 0x0004 ; i dont fucking know man

        this.hMapFile := DllCall("OpenFileMapping", "UInt", fileMapRead, "Int", 0, "Str", "RTSSSharedMemoryV2")
        if !this.hMapFile
        {
            throw Exception("Could not open RTSS Shared Memory. Is RivaTuner Statistics Server running?", -1)
        }

        this.pMapAddr := DllCall("MapViewOfFile", "Ptr", this.hMapFile, "UInt", fileMapRead, "UInt", 0, "UInt", 0, "Ptr", 0)
        if !this.pMapAddr
        {
            DllCall("CloseHandle", "Ptr", this.hMapFile)
            throw Exception("Failed to map view of shared memory. Why the fuck?", -2)
        }

        fn := this["_startMeasuringFrametime"].bind(this)
        SetTimer % fn, -500
    }

    __Delete() {
        if (this.pMapAddr)
            DllCall("UnmapViewOfFile", "Ptr", this.pMapAddr)

        if (this.hMapFile)
            DllCall("CloseHandle", "Ptr", this.hMapFile)
    }

    ; retrieve fps
    getFPS() {
        ; check if we have cached the address already
        if (this.processEntryAddress != 0) {
            return NumGet(this.processEntryAddress + this.fpsMemoryOffset, "UInt")
        } else {
            ; read the main header of the shared memory block
            dwAppArrOffset := NumGet(this.pMapAddr + 12, "UInt")
            dwAppArrSize := NumGet(this.pMapAddr + 16, "UInt")
            dwAppEntrySize := NumGet(this.pMapAddr + 8, "UInt")

            Loop % dwAppArrSize {
                ; calculate the starting address for the current applications data block
                entryBaseAddr := this.pMapAddr + dwAppArrOffset + (A_Index - 1) * dwAppEntrySize

                applicationName := StrGet(entryBaseAddr + 4, "CP0")

                ; check if its our target process
                if InStr(applicationName, this.targetProcess) {
                    ; store the entry address so we dont need to refind it everytime we want to get the games fps
                    this.processEntryAddress := entryBaseAddr

                    return NumGet(this.processEntryAddress + this.fpsMemoryOffset, "UInt")
                }
            }
        }

        return false ; why is there no null in ahk i love null
    }

    getFrametime() {
        return this.averageFrametime
    }

    ; retrieve frametime in ms
    _getRawFrametime() {
        if (this.processEntryAddress != 0) {
            return NumGet(this.processEntryAddress + this.frametimeMemoryOffset, "UInt") / 1000
        } else {
            dwAppArrOffset := NumGet(this.pMapAddr + 12, "UInt")
            dwAppArrSize := NumGet(this.pMapAddr + 16, "UInt")
            dwAppEntrySize := NumGet(this.pMapAddr + 8, "UInt")

            Loop % dwAppArrSize {
                entryBaseAddr := this.pMapAddr + dwAppArrOffset + (A_Index - 1) * dwAppEntrySize

                applicationName := StrGet(entryBaseAddr + 4, "CP0")

                if InStr(applicationName, this.targetProcess) {
                    this.processEntryAddress := entryBaseAddr

                    return NumGet(this.processEntryAddress + this.frametimeMemoryOffset, "UInt") / 1000
                }
            }
        }

        return false
    }

    _startMeasuringFrametime() { ; This is incredibly bad but I don't fucking care
        if (this.measuringFrametime) {
            throw Exception("Already measuring frametime!")
        }
        this.measuringFrametime := true
        DllCall("QueryPerformanceFrequency", "Int64*", timeFrequency)
        DllCall("QueryPerformanceCounter", "Int64*", originTime)
        this.timeFrequency := timeFrequency
        this.originTime := originTIme
        loop {
            this._updateFrameTimes()
        }
    }

    _updateFrameTimes() {
        DllCall("QueryPerformanceCounter", "Int64*", currentTime)
        now := (currentTime - this.originTime) * 1000 / this.timeFrequency
        currentFrametime := this._getRawFrametime() ; frametime in ms

        ; Add new entry
        this.frametimes.Push({time: now, frametime: currentFrametime})

        while (this.frametimes.Length() && (now - this.frametimes[1].time > this.averagingInterval)) {
            this.frametimes.RemoveAt(0)
        }

        ; Calculate average frametime
        total := 0
        for each, entry in this.frametimes {
            total += entry.frametime
        }

        count := this.frametimes.Length()
        this.averageFrametime := (count > 0) ? total / count : 0
    }
}
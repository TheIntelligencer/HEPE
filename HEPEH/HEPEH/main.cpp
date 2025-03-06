#include <stdio.h>
#include <atlstr.h>
#include <Windows.h>

#pragma warning(disable: 4005)
#pragma warning(disable: 4244)
#pragma warning(disable: 4996) // wcsnicmp deprecated

#include <winternl.h>
#include <ntstatus.h>

typedef struct __ZG_GPT_HEADER {
	CHAR	    Signature[8];
	__int32		Revision;
	__int32		HeaderSize;
	__int32		HeaderCRC32;
	__int32		Reserved;
	__int64 	MyLBA;
	__int64	    AlternateLBA;
	__int64 	FirstUsableLBA;
	__int64 	LastUsableLBA;
	UCHAR       DiskGUID[16];
	__int64     PartitionEntryLBA;
	__int32     NumberOfPartititonEntries;
	__int32     SizeOfPartititonEntry;
	__int32     PartitionEntryArrayCRC32;
} ZG_GPT_HEADER, *PZG_GPT_HEADER;

typedef struct __ZG_GPT_ENTRY {
	UCHAR	                PartitionTypeGUID[16];
	UCHAR	                UniquePartitionGUID[16];
	__int64	                StartingLBA;
	__int64	                EndingLBA;
	__int64	                Attributes;
	CHAR	                PartitionName[72];
} ZG_GPT_ENTRY, *PZG_GPT_ENTRY;

extern "C"
{
    __declspec(dllexport) __int64 ZgFileSeek(HANDLE file, __int64 distance, DWORD MoveMethod);
    __declspec(dllexport) BOOLEAN ZgGetDriveVendor(PCHAR Drive, PCHAR outbuffer, size_t outbuffersize);
    __declspec(dllexport) BOOLEAN ZgGetDriveModel(PCHAR Drive, PCHAR outbuffer, size_t outbuffersize);
    __declspec(dllexport) BOOLEAN ZgGetDriveRevision(PCHAR Drive, PCHAR outbuffer, size_t outbuffersize);
    __declspec(dllexport) BOOLEAN ZgGetSymLinkTarget(PCHAR filename, PCHAR outbuffer, size_t outbuffersize);
    __declspec(dllexport) DWORD ZgGetPartitionStyleInformation(PCHAR DrivePath);
    __declspec(dllexport) BOOL ZgIsDiskGPT(PCHAR DiskName);
    __declspec(dllexport) DWORD ZgQueryGPTPartitionsCount(PCHAR diskname);
    __declspec(dllexport) BOOL ZgQueryGPTPartitionInformationByIndex(PCHAR diskname, PZG_GPT_ENTRY info, DWORD index);
    __declspec(dllexport) DWORD ZgGetDriveSectorSize(PCHAR DriveName);
    __declspec(dllexport) BOOL ZgWriteZeroBlockToTarget(HANDLE target, ULONG blocksize);
    __declspec(dllexport) NTSTATUS ZgWriteZeroBlockToTarget2(HANDLE target, ULONG blocksize);
}

// This macro assures that INVALID_HANDLE_VALUE (0xFFFFFFFF) returns FALSE
#define IsConsoleHandle(h) (((((ULONG_PTR)h) & 0x10000003) == 0x3) ? TRUE : FALSE)

#define ZG_OBJ_NAME_INFORMATION 1

typedef struct __OBJECT_NAME_INFORMATION 
{
    UNICODE_STRING Name; // defined in winternl.h
    WCHAR NameBuffer;
} OBJECT_NAME_INFORMATION;

typedef NTSTATUS (NTAPI* t_NtQueryObject)(HANDLE Handle, OBJECT_INFORMATION_CLASS Info, PVOID Buffer, ULONG BufferSize, PULONG ReturnLength);

t_NtQueryObject NtQueryObject()
{
    static t_NtQueryObject f_NtQueryObject = NULL;
    if (!f_NtQueryObject)
    {
        HMODULE h_NtDll = GetModuleHandle(L"Ntdll.dll"); // Ntdll is loaded into EVERY process!
        f_NtQueryObject = (t_NtQueryObject)GetProcAddress(h_NtDll, "NtQueryObject");
    }
    return f_NtQueryObject;
}

// returns
// "\Device\HarddiskVolume3"                                (Harddisk Drive)
// "\Device\HarddiskVolume3\Temp"                           (Harddisk Directory)
// "\Device\HarddiskVolume3\Temp\transparent.jpeg"          (Harddisk File)
// "\Device\Harddisk1\DP(1)0-0+6\foto.jpg"                  (USB stick)
// "\Device\TrueCryptVolumeP\Data\Passwords.txt"            (Truecrypt Volume)
// "\Device\Floppy0\Autoexec.bat"                           (Floppy disk)
// "\Device\CdRom1\VIDEO_TS\VTS_01_0.VOB"                   (DVD drive)
// "\Device\Serial1"                                        (real COM port)
// "\Device\USBSER000"                                      (virtual COM port)
// "\Device\Mup\ComputerName\C$\Boot.ini"                   (network drive share,  Windows 7)
// "\Device\LanmanRedirector\ComputerName\C$\Boot.ini"      (network drive share,  Windwos XP)
// "\Device\LanmanRedirector\ComputerName\Shares\Dance.m3u" (network folder share, Windwos XP)
// "\Device\Afd"                                            (internet socket)
// "\Device\Console000F"                                    (unique name for any Console handle)
// "\Device\NamedPipe\Pipename"                             (named pipe)
// "\BaseNamedObjects\Objectname"                           (named mutex, named event, named semaphore)
// "\REGISTRY\MACHINE\SOFTWARE\Classes\.txt"                (HKEY_CLASSES_ROOT\.txt)
DWORD GetNtPathFromHandle(HANDLE h_File, CString* ps_NTPath)
{
    if (h_File == 0 || h_File == INVALID_HANDLE_VALUE)
        return ERROR_INVALID_HANDLE;

    // NtQueryObject() returns STATUS_INVALID_HANDLE for Console handles
    if (IsConsoleHandle(h_File))
    {
        ps_NTPath->Format(L"\\Device\\Console%04X", (DWORD)(DWORD_PTR)h_File);
        return 0;
    }

    BYTE  u8_Buffer[2000];
    DWORD u32_ReqLength = 0;

    UNICODE_STRING* pk_Info = &((OBJECT_NAME_INFORMATION*)u8_Buffer)->Name;
    pk_Info->Buffer = 0;
    pk_Info->Length = 0;

    // IMPORTANT: The return value from NtQueryObject is bullshit! (driver bug?)
    // - The function may return STATUS_NOT_SUPPORTED although it has successfully written to the buffer.
    // - The function returns STATUS_SUCCESS although h_File == 0xFFFFFFFF
    NtQueryObject()(h_File, (OBJECT_INFORMATION_CLASS)ZG_OBJ_NAME_INFORMATION, u8_Buffer, sizeof(u8_Buffer), &u32_ReqLength);

    // On error pk_Info->Buffer is NULL
    if (!pk_Info->Buffer || !pk_Info->Length)
        return ERROR_FILE_NOT_FOUND;

    pk_Info->Buffer[pk_Info->Length /2] = 0; // Length in Bytes!

    *ps_NTPath = pk_Info->Buffer;
    return 0;
}

// converts
// "\Device\HarddiskVolume3"                                -> "E:"
// "\Device\HarddiskVolume3\Temp"                           -> "E:\Temp"
// "\Device\HarddiskVolume3\Temp\transparent.jpeg"          -> "E:\Temp\transparent.jpeg"
// "\Device\Harddisk1\DP(1)0-0+6\foto.jpg"                  -> "I:\foto.jpg"
// "\Device\TrueCryptVolumeP\Data\Passwords.txt"            -> "P:\Data\Passwords.txt"
// "\Device\Floppy0\Autoexec.bat"                           -> "A:\Autoexec.bat"
// "\Device\CdRom1\VIDEO_TS\VTS_01_0.VOB"                   -> "H:\VIDEO_TS\VTS_01_0.VOB"
// "\Device\Serial1"                                        -> "COM1"
// "\Device\USBSER000"                                      -> "COM4"
// "\Device\Mup\ComputerName\C$\Boot.ini"                   -> "\\ComputerName\C$\Boot.ini"
// "\Device\LanmanRedirector\ComputerName\C$\Boot.ini"      -> "\\ComputerName\C$\Boot.ini"
// "\Device\LanmanRedirector\ComputerName\Shares\Dance.m3u" -> "\\ComputerName\Shares\Dance.m3u"
// returns an error for any other device type
DWORD GetDosPathFromNtPath(const WCHAR* u16_NTPath, CString* ps_DosPath)
{
    DWORD u32_Error;

    if (wcsnicmp(u16_NTPath, L"\\Device\\Serial", 14) == 0 || // e.g. "Serial1"
        wcsnicmp(u16_NTPath, L"\\Device\\UsbSer", 14) == 0)   // e.g. "USBSER000"
    {
        HKEY h_Key; 
        if (u32_Error = RegOpenKeyEx(HKEY_LOCAL_MACHINE, L"Hardware\\DeviceMap\\SerialComm", 0, KEY_QUERY_VALUE, &h_Key))
            return u32_Error;

        WCHAR u16_ComPort[50];

        DWORD u32_Type;
        DWORD u32_Size = sizeof(u16_ComPort); 
        if (u32_Error = RegQueryValueEx(h_Key, u16_NTPath, 0, &u32_Type, (BYTE*)u16_ComPort, &u32_Size))
        {
            RegCloseKey(h_Key);
            return ERROR_UNKNOWN_PORT;
        }

        *ps_DosPath = u16_ComPort;
        RegCloseKey(h_Key);
        return 0;
    }

    if (wcsnicmp(u16_NTPath, L"\\Device\\LanmanRedirector\\", 25) == 0) // Win XP
    {
        *ps_DosPath  = L"\\\\";
        *ps_DosPath += (u16_NTPath + 25);
        return 0;
    }

    if (wcsnicmp(u16_NTPath, L"\\Device\\Mup\\", 12) == 0) // Win 7
    {
        *ps_DosPath  = L"\\\\";
        *ps_DosPath += (u16_NTPath + 12);
        return 0;
    }

    WCHAR u16_Drives[300];
    if (!GetLogicalDriveStrings(300, u16_Drives))
        return GetLastError();

    WCHAR* u16_Drv = u16_Drives;
    while (u16_Drv[0])
    {
        WCHAR* u16_Next = u16_Drv +wcslen(u16_Drv) +1;

        u16_Drv[2] = 0; // the backslash is not allowed for QueryDosDevice()

        WCHAR u16_NtVolume[1000];
        u16_NtVolume[0] = 0;

        // may return multiple strings!
        // returns very weird strings for network shares
        if (!QueryDosDevice(u16_Drv, u16_NtVolume, sizeof(u16_NtVolume) /2))
            return GetLastError();

        int s32_Len = (int)wcslen(u16_NtVolume);
        if (s32_Len > 0 && wcsnicmp(u16_NTPath, u16_NtVolume, s32_Len) == 0)
        {
            *ps_DosPath  =  u16_Drv;
            *ps_DosPath += (u16_NTPath + s32_Len);
            return 0;
        }

        u16_Drv = u16_Next;
    }
    return ERROR_BAD_PATHNAME;
}

BOOLEAN ZgGetDriveVendor(PCHAR Drive, PCHAR outbuffer, size_t outbuffersize)
{
    if (Drive == NULL) return FALSE;
    if (outbuffer == NULL) return FALSE;

    HANDLE                      HDrive;
    BOOLEAN                     bResult;
    DWORD                       retBytes;
    STORAGE_PROPERTY_QUERY      DriveQuery;
    STORAGE_DESCRIPTOR_HEADER   DriveDescriptorHeader;
    PSTORAGE_DEVICE_DESCRIPTOR  DriveQueryResult;
    PBYTE                       tmp;

    HDrive = CreateFileA(
        Drive,
        0,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL,
        OPEN_EXISTING,
        0,
        0
    );

    if (HDrive == INVALID_HANDLE_VALUE) return FALSE;

    memset(&DriveQuery, 0, sizeof(STORAGE_PROPERTY_QUERY));
    DriveQuery.PropertyId = StorageDeviceProperty;
    DriveQuery.QueryType = PropertyStandardQuery;

    bResult = DeviceIoControl(
        HDrive,
        IOCTL_STORAGE_QUERY_PROPERTY,
        &DriveQuery,
        sizeof(STORAGE_PROPERTY_QUERY),
        &DriveDescriptorHeader,
        sizeof(STORAGE_DESCRIPTOR_HEADER),
        &retBytes,
        NULL
    );

    if (!bResult)
    {
        CloseHandle(HDrive);
        return FALSE;
    }

    tmp = (PBYTE)malloc(DriveDescriptorHeader.Size);
    memset(tmp, 0, DriveDescriptorHeader.Size);

    bResult = DeviceIoControl(
        HDrive,
        IOCTL_STORAGE_QUERY_PROPERTY,
        &DriveQuery,
        sizeof(STORAGE_PROPERTY_QUERY),
        tmp,
        DriveDescriptorHeader.Size,
        &retBytes,
        NULL
    );

    if (!bResult)
    {
        free(tmp);
        CloseHandle(HDrive);
        return FALSE;
    }

    DriveQueryResult = (PSTORAGE_DEVICE_DESCRIPTOR)tmp;
    sprintf_s(outbuffer, outbuffersize, "%s", 
        DriveQueryResult->VendorIdOffset != 0 ? (const char *)(tmp + DriveQueryResult->VendorIdOffset):(""));

    free(tmp);
    CloseHandle(HDrive);
    return TRUE;
}

BOOLEAN ZgGetDriveModel(PCHAR Drive, PCHAR outbuffer, size_t outbuffersize)
{
    if (Drive == NULL) return FALSE;
    if (outbuffer == NULL) return FALSE;

    HANDLE                      HDrive;
    BOOLEAN                     bResult;
    DWORD                       retBytes;
    STORAGE_PROPERTY_QUERY      DriveQuery;
    STORAGE_DESCRIPTOR_HEADER   DriveDescriptorHeader;
    PSTORAGE_DEVICE_DESCRIPTOR  DriveQueryResult;
    PBYTE                       tmp;

    HDrive = CreateFileA(
        Drive,
        0,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL,
        OPEN_EXISTING,
        0,
        0
    );

    if (HDrive == INVALID_HANDLE_VALUE) return FALSE;

    memset(&DriveQuery, 0, sizeof(STORAGE_PROPERTY_QUERY));
    DriveQuery.PropertyId = StorageDeviceProperty;
    DriveQuery.QueryType = PropertyStandardQuery;

    bResult = DeviceIoControl(
        HDrive,
        IOCTL_STORAGE_QUERY_PROPERTY,
        &DriveQuery,
        sizeof(STORAGE_PROPERTY_QUERY),
        &DriveDescriptorHeader,
        sizeof(STORAGE_DESCRIPTOR_HEADER),
        &retBytes,
        NULL
    );

    if (!bResult)
    {
        CloseHandle(HDrive);
        return FALSE;
    }

    tmp = (PBYTE)malloc(DriveDescriptorHeader.Size);
    memset(tmp, 0, DriveDescriptorHeader.Size);

    bResult = DeviceIoControl(
        HDrive,
        IOCTL_STORAGE_QUERY_PROPERTY,
        &DriveQuery,
        sizeof(STORAGE_PROPERTY_QUERY),
        tmp,
        DriveDescriptorHeader.Size,
        &retBytes,
        NULL
    );

    if (!bResult)
    {
        free(tmp);
        CloseHandle(HDrive);
        return FALSE;
    }

    DriveQueryResult = (PSTORAGE_DEVICE_DESCRIPTOR)tmp;
    sprintf_s(outbuffer, outbuffersize, "%s", 
        DriveQueryResult->ProductIdOffset != 0 ? (const char *)(tmp + DriveQueryResult->ProductIdOffset):(""));

    free(tmp);
    CloseHandle(HDrive);
    return TRUE;
}

BOOLEAN ZgGetDriveRevision(PCHAR Drive, PCHAR outbuffer, size_t outbuffersize)
{
    if (Drive == NULL) return FALSE;
    if (outbuffer == NULL) return FALSE;

    HANDLE                      HDrive;
    BOOLEAN                     bResult;
    DWORD                       retBytes;
    STORAGE_PROPERTY_QUERY      DriveQuery;
    STORAGE_DESCRIPTOR_HEADER   DriveDescriptorHeader;
    PSTORAGE_DEVICE_DESCRIPTOR  DriveQueryResult;
    PBYTE                       tmp;

    HDrive = CreateFileA(
        Drive,
        0,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL,
        OPEN_EXISTING,
        0,
        0
    );

    if (HDrive == INVALID_HANDLE_VALUE) return FALSE;

    memset(&DriveQuery, 0, sizeof(STORAGE_PROPERTY_QUERY));
    DriveQuery.PropertyId = StorageDeviceProperty;
    DriveQuery.QueryType = PropertyStandardQuery;

    bResult = DeviceIoControl(
        HDrive,
        IOCTL_STORAGE_QUERY_PROPERTY,
        &DriveQuery,
        sizeof(STORAGE_PROPERTY_QUERY),
        &DriveDescriptorHeader,
        sizeof(STORAGE_DESCRIPTOR_HEADER),
        &retBytes,
        NULL
    );

    if (!bResult)
    {
        CloseHandle(HDrive);
        return FALSE;
    }

    tmp = (PBYTE)malloc(DriveDescriptorHeader.Size);
    memset(tmp, 0, DriveDescriptorHeader.Size);

    bResult = DeviceIoControl(
        HDrive,
        IOCTL_STORAGE_QUERY_PROPERTY,
        &DriveQuery,
        sizeof(STORAGE_PROPERTY_QUERY),
        tmp,
        DriveDescriptorHeader.Size,
        &retBytes,
        NULL
    );

    if (!bResult)
    {
        free(tmp);
        CloseHandle(HDrive);
        return FALSE;
    }

    DriveQueryResult = (PSTORAGE_DEVICE_DESCRIPTOR)tmp;
    sprintf_s(outbuffer, outbuffersize, "%s", 
        DriveQueryResult->ProductRevisionOffset != 0 ? (const char *)(tmp + DriveQueryResult->ProductRevisionOffset):(""));

    free(tmp);
    CloseHandle(HDrive);
    return TRUE;
}

BOOLEAN ZgGetSymLinkTarget(PCHAR filename, PCHAR outbuffer, size_t outbuffersize)
{
    if (filename == NULL) return FALSE;
    if (outbuffer == NULL) return FALSE;
    
    HANDLE                      hFile;
    HANDLE                      hAccessToken;
    LUID                        luidPrivilege;
    
    if (!OpenProcessToken(
        GetCurrentProcess(),
        TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY,
        &hAccessToken))
    {
        return FALSE;
    }

    if (LookupPrivilegeValue(NULL, SE_BACKUP_NAME, &luidPrivilege))
    {
        TOKEN_PRIVILEGES pv = {0};
        pv.PrivilegeCount = 1;
        pv.Privileges[0].Luid = luidPrivilege;
        pv.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
        AdjustTokenPrivileges(hAccessToken, FALSE, &pv, 0, NULL, NULL);
        if (GetLastError() != ERROR_SUCCESS)
        {
            CloseHandle(hAccessToken);
            return FALSE;
        }
    }
    else
    {
        CloseHandle(hAccessToken);
        return FALSE;
    }

    hFile = CreateFileA(
        filename,
        0,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS,
        NULL
    );

    if (hFile == INVALID_HANDLE_VALUE) 
    {
        CloseHandle(hAccessToken);
        return FALSE;
    }

    CString ntpath;
    if (GetNtPathFromHandle(hFile, &ntpath) != ERROR_SUCCESS)
    {
        CloseHandle(hFile);
        CloseHandle(hAccessToken);
        return FALSE;
    }

    CString dospath;
    if (GetDosPathFromNtPath(ntpath, &dospath) != ERROR_SUCCESS)
    {
        CloseHandle(hFile);
        CloseHandle(hAccessToken);
        return FALSE;
    }
    
    sprintf_s(outbuffer, outbuffersize, "%ws", dospath);

    CloseHandle(hFile);
    CloseHandle(hAccessToken);
    return TRUE;
}

DWORD ZgGetPartitionStyleInformation(PCHAR DrivePath)
{
    if (DrivePath == NULL) return -1;

    HANDLE                      hFile;
    DWORD                       retBytes;
    BOOL                        bResult;
    PARTITION_INFORMATION_EX    partinfo;

    hFile = CreateFileA(
        DrivePath,
        0,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS,
        NULL
    );

    if (hFile == INVALID_HANDLE_VALUE)
    {
        return -1;
    }

    bResult = DeviceIoControl(
        hFile,
        IOCTL_DISK_GET_PARTITION_INFO_EX,
        NULL,
        0,
        &partinfo,
        sizeof(PARTITION_INFORMATION_EX),
        &retBytes,
        NULL
    );

    if (!bResult)
    {
        CloseHandle(hFile);
        return -1;
    }

    CloseHandle(hFile);

    if (partinfo.PartitionStyle == PARTITION_STYLE_GPT)
        return 2; else
    if (partinfo.PartitionStyle == PARTITION_STYLE_MBR)
        return 1; else
    if (partinfo.PartitionStyle == PARTITION_STYLE_RAW)
        return 0; else
        return 3;
}

DWORD ZgGetDriveSectorSize(PCHAR DriveName)
{
    if (DriveName == NULL) return -1;

    HANDLE			targetdisk;
	BOOL			opresult;
	DISK_GEOMETRY	DiskGeo = {0};
	DWORD			retBytes = 0;
	DWORD			LBASize = 0;

    targetdisk = CreateFileA(DriveName, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
		NULL, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, NULL);

	if (targetdisk == INVALID_HANDLE_VALUE)
	{
		return -1;
	}

	opresult = DeviceIoControl(targetdisk, IOCTL_DISK_GET_DRIVE_GEOMETRY, NULL, 
		0, &DiskGeo, sizeof(DISK_GEOMETRY), &retBytes, NULL);

	if (opresult != TRUE)
	{
		CloseHandle(targetdisk);
		return -1;
	}

	LBASize = DiskGeo.BytesPerSector;

    CloseHandle(targetdisk);
    
    return LBASize;
}

//Move Method can be: FILE_BEGIN (as 0), FILE_CURRENT (as 1), FILE_END (as 2)
__int64 ZgFileSeek(HANDLE file, __int64 distance, DWORD MoveMethod)
{
	LARGE_INTEGER li;

	li.QuadPart = distance;

	li.LowPart = SetFilePointer(file,
		li.LowPart,
		&li.HighPart,
		MoveMethod);

	if ((li.LowPart == INVALID_SET_FILE_POINTER) &&
		(GetLastError() != NO_ERROR))
	{
		li.QuadPart = -1;
	}

	return li.QuadPart;
}

BOOL ZgIsGUIDNull(UCHAR input[16])
{
	BOOL result = TRUE;
	for (int i = 0; i < 16; ++i)
		result &= (input[i] == 0);
	return result;
}

BOOL ZgIsDiskGPT(PCHAR DiskName)
{
    if (DiskName == NULL)
        return FALSE;

	HANDLE			targetdisk;
	BOOL			opresult;
	DISK_GEOMETRY	DiskGeo = {0};
	DWORD			retBytes = 0;
	DWORD			LBASize = 0;
	ZG_GPT_HEADER	resultheader = {0};
	UCHAR			*rhmemory;

	targetdisk = CreateFileA(DiskName, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
		NULL, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, NULL);

	if (targetdisk == INVALID_HANDLE_VALUE)
	{
		return FALSE;
	}

	opresult = DeviceIoControl(targetdisk, IOCTL_DISK_GET_DRIVE_GEOMETRY, NULL, 
		0, &DiskGeo, sizeof(DISK_GEOMETRY), &retBytes, NULL);

	if (opresult != TRUE)
	{
		CloseHandle(targetdisk);
		return FALSE;
	}

	LBASize = DiskGeo.BytesPerSector;

	if (ZgFileSeek(targetdisk, LBASize, FILE_BEGIN) == -1)
	{
		CloseHandle(targetdisk);
		return FALSE;
	}

	rhmemory = (UCHAR *)malloc(sizeof(UCHAR) * LBASize);

	opresult = ReadFile(targetdisk, rhmemory, sizeof(UCHAR) * LBASize, &retBytes, NULL);

	if (opresult != TRUE)
	{
		free(rhmemory);
		CloseHandle(targetdisk);
		return FALSE;
	}

	memcpy(&(resultheader.Signature), rhmemory, sizeof(UCHAR) * 8);

	free(rhmemory);

	CloseHandle(targetdisk);

	if (strstr(resultheader.Signature, "EFI PART") != NULL)
	{
		return TRUE;
	}

	return FALSE;
}

BOOL ZgReadGPTHeader(PCHAR DiskName, PZG_GPT_HEADER gptheader)
{
    if (DiskName == NULL)
        return FALSE;

	if (gptheader == NULL)
	{
		return FALSE;
	}

	HANDLE			targetdisk;
	BOOL			opresult;
	DISK_GEOMETRY	DiskGeo = {0};
	DWORD			retBytes = 0;
	DWORD			LBASize = 0;
	ZG_GPT_HEADER	resultheader = {0};
	UCHAR			*rhmemory;

	targetdisk = CreateFileA(DiskName, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
		NULL, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, NULL);

	if (targetdisk == INVALID_HANDLE_VALUE)
	{
		return FALSE;
	}

	opresult = DeviceIoControl(targetdisk, IOCTL_DISK_GET_DRIVE_GEOMETRY, NULL, 
		0, &DiskGeo, sizeof(DISK_GEOMETRY), &retBytes, NULL);

	if (opresult != TRUE)
	{
		CloseHandle(targetdisk);
		return FALSE;
	}

	LBASize = DiskGeo.BytesPerSector;

	if (ZgFileSeek(targetdisk, LBASize, FILE_BEGIN) == -1)
	{
		CloseHandle(targetdisk);
		return FALSE;
	}

	rhmemory = (UCHAR *)malloc(sizeof(UCHAR) * LBASize);

	opresult = ReadFile(targetdisk, rhmemory, sizeof(UCHAR) * LBASize, &retBytes, NULL);

	if (opresult != TRUE)
	{
		free(rhmemory);
		CloseHandle(targetdisk);
		return FALSE;
	}

	memcpy(&(resultheader.Signature), rhmemory, sizeof(UCHAR) * 8);

	if (strstr(resultheader.Signature, "EFI PART") != NULL)
	{
		memcpy(&(resultheader.Signature), rhmemory, 8);
		memcpy(&(resultheader.Revision), rhmemory + 0x08, 4);
		memcpy(&(resultheader.HeaderSize), rhmemory + 0x0C, 4);
		memcpy(&(resultheader.HeaderCRC32), rhmemory + 0x10, 4);
		memcpy(&(resultheader.Reserved), rhmemory + 0x14, 4);
		memcpy(&(resultheader.MyLBA), rhmemory + 0x18, 8);
		memcpy(&(resultheader.AlternateLBA), rhmemory + 0x20, 8);
		memcpy(&(resultheader.FirstUsableLBA), rhmemory + 0x28, 8);
		memcpy(&(resultheader.LastUsableLBA), rhmemory + 0x30, 8);
		memcpy(&(resultheader.DiskGUID), rhmemory + 0x38, 16);
		memcpy(&(resultheader.PartitionEntryLBA), rhmemory + 0x48, 8);
		memcpy(&(resultheader.NumberOfPartititonEntries), rhmemory + 0x50, 4);
		memcpy(&(resultheader.SizeOfPartititonEntry), rhmemory + 0x54, 4);
		memcpy(&(resultheader.PartitionEntryArrayCRC32), rhmemory + 0x58, 4);

		memcpy(gptheader, &resultheader, sizeof(ZG_GPT_HEADER));

		free(rhmemory);

		CloseHandle(targetdisk);

		return TRUE;
	}

	free(rhmemory);

	CloseHandle(targetdisk);

	return FALSE;
}

DWORD ZgQueryGPTPartitionsCount(PCHAR diskname)
{
    if (diskname == NULL) return -1;

    if (!ZgIsDiskGPT(diskname)) return -1;

    ZG_GPT_HEADER   gptheader;
    DWORD           partcount = 0;
    HANDLE			targetdisk;
	BOOL			opresult;
	DISK_GEOMETRY	DiskGeo = {0};
	DWORD			retBytes = 0;
    UCHAR			*rawdata = NULL;
    DWORD           startpos = 0;
    DWORD           bytesCountToRead = 0;
    DWORD			readstep = 0;

    if (!ZgReadGPTHeader(diskname, &gptheader)) return FALSE;

    targetdisk = CreateFileA(diskname, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
		NULL, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, NULL);

    if (targetdisk == INVALID_HANDLE_VALUE)
	{
		return -1;
	}

	opresult = DeviceIoControl(targetdisk, IOCTL_DISK_GET_DRIVE_GEOMETRY, NULL, 
		0, &DiskGeo, sizeof(DISK_GEOMETRY), &retBytes, NULL);

	if (opresult != TRUE)
	{
		CloseHandle(targetdisk);
		return -1;
	}

	startpos = DiskGeo.BytesPerSector * gptheader.PartitionEntryLBA;

    if (ZgFileSeek(targetdisk, startpos, FILE_BEGIN) == -1)
    {
        CloseHandle(targetdisk);
		return -1;
    }

    bytesCountToRead = DiskGeo.BytesPerSector * ((gptheader.FirstUsableLBA - 1) - gptheader.PartitionEntryLBA);
    readstep = gptheader.SizeOfPartititonEntry;
    rawdata = (UCHAR *)malloc(bytesCountToRead);

    opresult = ReadFile(targetdisk, rawdata, bytesCountToRead,&retBytes, NULL);

    if (!opresult)
    {
        free(rawdata);
        CloseHandle(targetdisk);
        return -1;
    }

    for (DWORD i = 0; i < bytesCountToRead; i += readstep)
    {
        if (!ZgIsGUIDNull(((PZG_GPT_ENTRY)(rawdata + i))->PartitionTypeGUID))
            partcount++;
    }

    free(rawdata);
	CloseHandle(targetdisk);
    return partcount;
}

BOOL ZgQueryGPTPartitionInformationByIndex(PCHAR diskname, PZG_GPT_ENTRY info, DWORD index)
{
    if (diskname == NULL) return FALSE;
    if (info == NULL) return FALSE;

    DWORD partcount = ZgQueryGPTPartitionsCount(diskname);

    if ((index < 0) || (index >= partcount)) return FALSE;

    ZG_GPT_HEADER   gptheader;
    HANDLE			targetdisk;
	BOOL			opresult;
	DISK_GEOMETRY	DiskGeo = {0};
	DWORD			retBytes = 0;
    UCHAR			*rawdata = NULL;
    DWORD           startpos = 0;
    DWORD           bytesCountToRead = 0;
    DWORD			readstep = 0;

    if (!ZgReadGPTHeader(diskname, &gptheader)) return FALSE;

    targetdisk = CreateFileA(diskname, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
		NULL, OPEN_EXISTING, FILE_FLAG_NO_BUFFERING, NULL);

    if (targetdisk == INVALID_HANDLE_VALUE)
	{
		return FALSE;
	}

	opresult = DeviceIoControl(targetdisk, IOCTL_DISK_GET_DRIVE_GEOMETRY, NULL, 
		0, &DiskGeo, sizeof(DISK_GEOMETRY), &retBytes, NULL);

	if (opresult != TRUE)
	{
		CloseHandle(targetdisk);
		return FALSE;
	}

	startpos = DiskGeo.BytesPerSector * gptheader.PartitionEntryLBA;

    if (ZgFileSeek(targetdisk, startpos, FILE_BEGIN) == -1)
    {
        CloseHandle(targetdisk);
		return FALSE;
    }

    bytesCountToRead = DiskGeo.BytesPerSector * ((gptheader.FirstUsableLBA - 1) - gptheader.PartitionEntryLBA);
    readstep = gptheader.SizeOfPartititonEntry * index;
    rawdata = (UCHAR *)malloc(bytesCountToRead);

    opresult = ReadFile(targetdisk, rawdata, bytesCountToRead, &retBytes, NULL);

    if (!opresult)
    {
        free(rawdata);
        CloseHandle(targetdisk);
        return FALSE;
    }

    DWORD actualsize = gptheader.SizeOfPartititonEntry - (gptheader.SizeOfPartititonEntry - sizeof(ZG_GPT_ENTRY));
    memcpy(info, (rawdata + readstep), actualsize);

    free(rawdata);
	CloseHandle(targetdisk);
    return TRUE;
}

#define ZG_32MB_BLOCKSIZE 33554432

__int64 ZgGetFileCurrentPos(HANDLE file)
{
	return ZgFileSeek(file, 0, FILE_CURRENT);
}

BOOL ZgWriteZeroBlockToTarget(HANDLE target, ULONG blocksize)
{
    if (blocksize == 0) return TRUE;

    PVOID mem = malloc(blocksize);
    RtlZeroMemory(mem, blocksize);

    DWORD retBytes = 0;
    BOOL opresult = WriteFile(target, mem, blocksize, &retBytes, NULL);
    
    free(mem);

    return opresult;
}

typedef NTSTATUS (NTAPI *NTWRITEFILE)(
    IN HANDLE               FileHandle,
    IN HANDLE               Event OPTIONAL,
    IN PIO_APC_ROUTINE      ApcRoutine OPTIONAL,
    IN PVOID                ApcContext OPTIONAL,
    OUT PIO_STATUS_BLOCK    IoStatusBlock,
    IN PVOID                Buffer,
    IN ULONG                Length,
    IN PLARGE_INTEGER       ByteOffset OPTIONAL,
    IN PULONG               Key OPTIONAL
);

NTSTATUS ZgWriteZeroBlockToTarget2(HANDLE target, ULONG blocksize)
{
    if (blocksize == 0) return STATUS_SUCCESS;

    HMODULE NTDLL = LoadLibraryA("ntdll.dll");
    if (NTDLL == INVALID_HANDLE_VALUE) return STATUS_DLL_NOT_FOUND;

    NTWRITEFILE NtWriteFile = (NTWRITEFILE)GetProcAddress(NTDLL, "NtWriteFile");
    if (NtWriteFile == NULL)
    {
        FreeLibrary(NTDLL);
        return STATUS_ENTRYPOINT_NOT_FOUND;
    }

    PVOID mem = malloc(blocksize);
    RtlZeroMemory(mem, blocksize);
    
    DWORD retBytes = 0;
    IO_STATUS_BLOCK iostatusblock = {0};
    NTSTATUS opresult = NtWriteFile(
        target,
        NULL,
        NULL,
        NULL,
        &iostatusblock,
        mem,
        blocksize,
        NULL,
        NULL
    ); 
    
    free(mem);
    FreeLibrary(NTDLL);

    return opresult;
}

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
					 )
{
	switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		break;
	}
	return TRUE;
}
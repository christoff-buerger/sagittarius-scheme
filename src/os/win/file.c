/*  file.c                                         -*- mode:c; coding:utf-8; -*-
 *
 *   Copyright (c) 2010-2015  Takashi Kato <ktakashi@ymail.com>
 *
 *   Redistribution and use in source and binary forms, with or without
 *   modification, are permitted provided that the following conditions
 *   are met:
 *
 *   1. Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *
 *   2. Redistributions in binary form must reproduce the above copyright
 *      notice, this list of conditions and the following disclaimer in the
 *      documentation and/or other materials provided with the distribution.
 *
 *   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 *   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 *   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 *   A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 *   OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 *   SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 *   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 *   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 *   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 *   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *  $Id: $
 */
#include <windows.h>
#include <shlwapi.h>
#include <wchar.h>
#include <io.h>
#include <string.h>
#define LIBSAGITTARIUS_BODY
#include <sagittarius/file.h>
#include <sagittarius/codec.h>
#include <sagittarius/port.h>
#include <sagittarius/pair.h>
#include <sagittarius/transcoder.h>
#include <sagittarius/string.h>
#include <sagittarius/error.h>
#include <sagittarius/symbol.h>
#include <sagittarius/system.h>
#include <sagittarius/unicode.h>
#include <sagittarius/number.h>

#if defined(_MSC_VER) || defined(_SG_WIN_SUPPORT)
#pragma comment(lib, "shlwapi.lib")
#endif

typedef struct FD_tag
{
  HANDLE desc;
  DWORD  lastError;
  int    prevChar;
} FD;

#define SG_FILE_DEP(f) (SG_FILE(f)->osdependance)
#define SG_FD(o)  ((FD*)(SG_FILE_DEP(o)))
#define setLastError(file) (SG_FD(file)->lastError = GetLastError())

#define F_OK 0
#define W_OK 2
#define R_OK 4

static int64_t win_read(SgObject self, uint8_t *buf, int64_t size)
{
  DWORD readSize = 0;
  int isOK;
  /* check console */
  if (Sg_IsUTF16Console(self)) {
    ASSERT(size == 1);
    if (SG_FD(self)->prevChar != -1) {
      isOK = TRUE;
      readSize = 1;
      *buf = (uint8_t)(SG_FD(self)->prevChar);
      SG_FD(self)->prevChar = -1;
    } else {
      wchar_t wc = 0;
      isOK = ReadConsoleW(SG_FD(self)->desc, &wc, 1, &readSize, NULL);
      if (isOK) {
	readSize = 1;
	*buf = (uint8_t)(wc);
	SG_FD(self)->prevChar = wc >> 8;
      }
    }
  } else {
    isOK = ReadFile(SG_FD(self)->desc, buf, (DWORD)size, &readSize, NULL);
    if (!isOK) {
      DWORD err = GetLastError();
      switch (err) {
      case ERROR_BROKEN_PIPE: return 0;
      default: break;
      }
    }
  }
  setLastError(SG_FILE(self));
  if (isOK) {
    return readSize;
  } else {
    return -1;
  }
}

static int64_t win_write(SgObject self, uint8_t *buf, int64_t size)
{
  DWORD writeSize = 0;
  int isOK;
  SgFile *file = SG_FILE(self);
  /* check console */
  if (Sg_IsUTF16Console(file)) {
#if 1
    unsigned int destSize = 0;
    uint8_t *dest = NULL;
    if ((destSize = WideCharToMultiByte(GetConsoleOutputCP(), 0,
					(const wchar_t *)buf, 
					(DWORD)(size / 2), 
					(LPSTR)NULL, 0, NULL, NULL)) == 0) {
      Sg_IOWriteError(SG_INTERN("write"), Sg_GetLastErrorMessage(), SG_UNDEF);
    }
    dest = SG_NEW_ATOMIC2(uint8_t *, destSize + 1);
    if (WideCharToMultiByte(GetConsoleOutputCP(), 0, (const wchar_t *)buf,
			    (DWORD)(size / 2),
			    (LPSTR)dest, destSize, NULL, NULL) == 0) {
      Sg_IOWriteError(SG_INTERN("write"), Sg_GetLastErrorMessage(), SG_UNDEF);
    }
    isOK = WriteFile(SG_FD(file)->desc, dest, destSize, &writeSize, NULL);
    if (writeSize != destSize) {
      Sg_IOWriteError(SG_INTERN("write"), Sg_GetLastErrorMessage(), SG_UNDEF);
    }
    writeSize = (DWORD)size;
#else
    isOK = WriteFile(SG_FD(file)->desc, buf, size, &writeSize, NULL);
#endif
  } else {
    isOK = WriteFile(SG_FD(file)->desc, buf, (DWORD)size, &writeSize, NULL);
  }
  setLastError(file);
  if (isOK) {
    return writeSize;
  } else {
    return -1;
  }
}

static int64_t win_seek(SgObject self, int64_t offset, Whence whence)
{
  LARGE_INTEGER largePos, resultPos = {0};
  DWORD posMode;
  BOOL isOK;
  largePos.QuadPart = offset;
  switch (whence) {
  case SG_BEGIN:
    posMode = FILE_BEGIN; break;
  case SG_CURRENT:
    posMode = FILE_CURRENT; break;
  case SG_END:
    posMode = FILE_END; break;
  }
  isOK = SetFilePointerEx(SG_FD(SG_FILE(self))->desc, largePos, &resultPos,
			  posMode);
  setLastError(SG_FILE(self));
  if (isOK) {
    return resultPos.QuadPart;
  } else {
    return -1;
  }
  return 0;
}

static int64_t win_tell(SgObject self)
{
  return win_seek(self, 0, SG_CURRENT);
}

static int win_is_open(SgObject self)
{
  SgFile *file = SG_FILE(self);
  return SG_FD(file)->desc != INVALID_HANDLE_VALUE;
}

#include "win_util.c"

static int win_open(SgObject self, SgString *path, int flags)
{
  SgFile *file = SG_FILE(self);
  file->name = path->value;
  if (SG_FILE_VTABLE(file)->isOpen(file)) {
    return FALSE;
  } else {
    DWORD access = 0, disposition = 0;
    DWORD share = FILE_SHARE_READ | FILE_SHARE_WRITE;
    const wchar_t *u16path;
    switch (flags) {
    case SG_READ | SG_WRITE | SG_CREATE:
        access = GENERIC_READ | GENERIC_WRITE;
        disposition = OPEN_ALWAYS;
        break;
    case SG_READ | SG_WRITE | SG_CREATE | SG_TRUNCATE:
        access = GENERIC_READ | GENERIC_WRITE;
        disposition = CREATE_ALWAYS;
        break;
    case SG_READ:
        access = GENERIC_READ;
        disposition = OPEN_EXISTING;
        break;
    case SG_WRITE | SG_CREATE:
        access = GENERIC_WRITE;
        disposition = OPEN_ALWAYS;
        break;
    case SG_WRITE | SG_CREATE | SG_TRUNCATE:
        access = GENERIC_READ | GENERIC_WRITE;
        disposition = CREATE_ALWAYS;
        break;
    default:
        ASSERT(0);
    }
    u16path = utf32ToUtf16(path);
    SG_FD(file)->desc = CreateFileW(u16path, access, share, NULL,
				    disposition, FILE_ATTRIBUTE_NORMAL, NULL);
  }
  setLastError(file);
  return SG_FILE_VTABLE(file)->isOpen(file);
}

static int win_close(SgObject self)
{
  SgFile *file = SG_FILE(self);
  FlushFileBuffers(SG_FD(file)->desc);
  if (SG_FILE_VTABLE(file)->isOpen(file)
      && !(SG_FD(file)->desc == GetStdHandle(STD_OUTPUT_HANDLE)
	   || SG_FD(file)->desc == GetStdHandle(STD_INPUT_HANDLE)
	   || SG_FD(file)->desc == GetStdHandle(STD_ERROR_HANDLE))) {
    const int isOK = (CloseHandle(SG_FD(file)->desc) != 0);
    setLastError(file);
    SG_FD(file)->desc = INVALID_HANDLE_VALUE;
    return isOK;
  }
  return FALSE;
}

static int win_can_close(SgObject self)
{
  SgFile *file = SG_FILE(self);
  return (SG_FILE_VTABLE(file)->isOpen(file)
	  && !(SG_FD(file)->desc == GetStdHandle(STD_OUTPUT_HANDLE)
	       || SG_FD(file)->desc == GetStdHandle(STD_INPUT_HANDLE)
	       || SG_FD(file)->desc == GetStdHandle(STD_ERROR_HANDLE)));
}

static int64_t win_size(SgObject self)
{
  LARGE_INTEGER size = {0};
  int isOK = GetFileSizeEx(SG_FD(self)->desc, &size);
  setLastError(self);
  if (isOK) {
    return size.QuadPart;
  } else {
    return -1;
  }
}

static int check_char_type(SgObject self)
{
  INPUT_RECORD inRec[32];
  DWORD numRec;
  if (PeekConsoleInput(SG_FD(self)->desc, inRec, 
		       array_sizeof(inRec), &numRec)) {
    int i;
    for (i = 0; i < numRec; i++) {
      if (inRec[i].EventType == KEY_EVENT) return TRUE;
    }
  }
  return FALSE;
}

static int check_pipe_type(SgObject self)
{
  DWORD bytes;
  if (PeekNamedPipe(SG_FD(self)->desc, NULL, 0, NULL, &bytes, NULL)) {
    return (bytes != 0);
  } else {
    return FALSE;
  }
}

static int win_ready(SgObject self)
{
  if (SG_FD(self)->desc != INVALID_HANDLE_VALUE) {
    switch (GetFileType(SG_FD(self)->desc)) {
    case FILE_TYPE_CHAR: return check_char_type(self);
    case FILE_TYPE_PIPE: return check_pipe_type(self);
    }
    /* should not reach here, but default is default ... */
    return TRUE;
  } else {
    return FALSE;
  }
}

static SgFileTable vtable = {
  win_read,
  win_write,
  win_seek,
  win_tell,
  win_size,
  win_is_open,
  win_open,
  win_close,
  win_can_close,
  win_ready
};

static SgFile* init_file(SgFile *file, HANDLE hd)
{
  FD *depend = SG_NEW(FD);
  SG_SET_CLASS(file, SG_CLASS_FILE);
  depend->desc = hd;
  depend->lastError = 0;
  depend->prevChar = -1;
  file->osdependance = (void*)depend;
  return file;
}

SgObject Sg_MakeFile()
{
  SgFile *z = SG_NEW(SgFile);
  return Sg_InitFile(z);
}

SgObject Sg_InitFile(SgFile *file)
{
  init_file(file, INVALID_HANDLE_VALUE);
  SG_FILE_VTABLE(file) = &vtable;
  return SG_OBJ(file);
}

SgObject Sg_FileErrorMessage(SgObject file)
{
  return get_last_error(SG_FD(file)->lastError);
}

int Sg_LockFile(SgObject file, enum SgFileLockType mode)
{
  DWORD flag = 0;
  LARGE_INTEGER bsize = {0};
  OVERLAPPED overlapped;
  if (mode & SG_EXCLUSIVE) flag |= LOCKFILE_EXCLUSIVE_LOCK;
  if (mode & SG_DONT_WAIT) flag |= LOCKFILE_FAIL_IMMEDIATELY;

  GetFileSizeEx(SG_FD(file)->desc, &bsize);
  
  overlapped.hEvent = NULL;
  if (LockFileEx(SG_FD(file)->desc, flag, (DWORD)0,
		 bsize.LowPart, bsize.HighPart, &overlapped) == 0) {
    setLastError(file);
    return FALSE;
  }
  return TRUE;
}

int Sg_UnlockFile(SgObject file)
{
  OVERLAPPED overlapped;
  LARGE_INTEGER bsize = {0};

  GetFileSizeEx(SG_FD(file)->desc, &bsize);

  overlapped.hEvent = NULL;
  if (!UnlockFileEx(SG_FD(file)->desc, (DWORD)0, 
		    bsize.LowPart, bsize.HighPart, &overlapped)) {
    setLastError(file);
    return FALSE;
  }
  return TRUE;
}


static SgFile *stdOut = NULL;
static SgFile *stdIn = NULL;
static SgFile *stdError = NULL;

SgObject Sg_StandardOut()
{
  if (!stdOut) {
    stdOut = Sg_MakeFileFromFD(GetStdHandle(STD_OUTPUT_HANDLE));
    stdOut->name = UC("stdout");
  }
  return SG_OBJ(stdOut);
}

SgObject Sg_StandardIn()
{
  if (!stdIn) {
    stdIn = Sg_MakeFileFromFD(GetStdHandle(STD_INPUT_HANDLE));
    stdIn->name = UC("stdin");
  }
  return SG_OBJ(stdIn);
}

SgObject Sg_StandardError()
{
  if (!stdError) {
    stdError = Sg_MakeFileFromFD(GetStdHandle(STD_ERROR_HANDLE));
    stdError->name = UC("stderr");
  }
  return SG_OBJ(stdError);
}

SgObject Sg_MakeFileFromFD(uintptr_t handle)
{
  SgFile *f = SG_NEW(SgFile);
  init_file(f, (HANDLE)handle);
  f->name = UC("fd");
  SG_FILE_VTABLE(f) = &vtable;
  return SG_OBJ(f);
}

int Sg_IsUTF16Console(SgObject file)
{
  return GetFileType(SG_FD(file)->desc) == FILE_TYPE_CHAR;
}

/* system.h
   we need to merge the file.
 */
int Sg_FileExistP(SgString *path)
{
  return (_waccess(utf32ToUtf16(path), F_OK) == 0); 
}

int Sg_DeleteFile(SgString *path)
{
  /* for posix remove, it need to return 0 when succeed */
  return DeleteFileW(utf32ToUtf16(path)) ? 0 : -1;
}

int Sg_CopyFile(SgString *src, SgString *dst, int overwriteP)
{
  return CopyFileW(utf32ToUtf16(src), utf32ToUtf16(dst), !overwriteP);
}

/* Originally from Mosh start */
int Sg_FileWritableP(SgString *path)
{
  return _waccess(utf32ToUtf16(path), W_OK | F_OK) == 0; 
}

int Sg_FileReadableP(SgString *path)
{
  return _waccess(utf32ToUtf16(path), R_OK) == 0; 
}

int Sg_FileRegularP(SgString *path)
{
    HANDLE fd = CreateFileW(utf32ToUtf16(path), 0, 0,
			    NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (fd != INVALID_HANDLE_VALUE) {
        DWORD type = GetFileType(fd) & ~FILE_TYPE_REMOTE;
        CloseHandle(fd);
        return (type == FILE_TYPE_DISK);
    }
    return FALSE;
}

int Sg_FileSymbolicLinkP(SgString *path)
{
    DWORD attr = GetFileAttributesW(utf32ToUtf16(path));
    if (attr == INVALID_FILE_ATTRIBUTES) {
        return FALSE;
    }
    return (attr & FILE_ATTRIBUTE_REPARSE_POINT);
}

static int end_with(const SgString *target, const char * key)
{
  size_t size = SG_STRING_SIZE(target);
  size_t keysize = strlen(key);
  size_t i, off = size - keysize;
  int j;
  for (i = off, j = 0; j < keysize; i++, j++) {
    if (Sg_CharUpCase(SG_STRING_VALUE_AT(target, i)) != key[j]) return FALSE;
  }
  return TRUE;
}

int Sg_FileExecutableP(SgString *path)
{
    if (Sg_FileExistP(path)) {
      const char* pathext[] = { ".COM", ".EXE", ".BAT", ".VBS", ".VBE",
				".JS",  ".JSE", ".WSF", ".WSH", ".MSC" };
      unsigned int i;
      for (i = 0; i < array_sizeof(pathext); i++) {
	if (end_with(path, pathext[i])) return TRUE;
      }
    }
    return FALSE;
}

int Sg_DirectoryP(SgString *path)
{
  return PathIsDirectoryW(utf32ToUtf16(path));
}

int Sg_DeleteFileOrDirectory(SgString *path)
{
  wchar_t *wpath = utf32ToUtf16(path);
  if (PathIsDirectoryW(wpath)) {
    return RemoveDirectoryW(wpath);
  } else {
    return DeleteFileW(wpath);
  }
}

int Sg_FileRename(SgString *oldpath, SgString *newpath)
{
  return MoveFileExW(utf32ToUtf16(oldpath),
		     utf32ToUtf16(newpath),
		     MOVEFILE_REPLACE_EXISTING);
}

void Sg_ChangeFileMode(SgString *path, int mode)
{
  /* no operation on windows */
  if (!Sg_FileExistP(path)) {
    Sg_IOError(SG_IO_FILE_NOT_EXIST_ERROR, SG_INTERN("change-file-mode"),
	       Sg_GetLastErrorMessage(), path, SG_FALSE);
  }
}

typedef BOOL (WINAPI* ProcCreateSymbolicLink) (LPCWSTR, LPCWSTR, DWORD);

int Sg_CreateSymbolicLink(SgString *oldpath, SgString *newpath)
{
    ProcCreateSymbolicLink win32CreateSymbolicLink
      = (ProcCreateSymbolicLink)GetProcAddress(LoadLibraryA("kernel32"),
					       "CreateSymbolicLinkW");
    if (win32CreateSymbolicLink) {
      const wchar_t* newPathW = utf32ToUtf16(newpath);
      const wchar_t* oldPathW = utf32ToUtf16(oldpath);
      /* SYMBOLIC_LINK_FLAG_DIRECTORY == 1 */
      DWORD flag = PathIsDirectoryW(oldPathW) ? 1 : 0;
      if (win32CreateSymbolicLink(newPathW, oldPathW, flag)) {
	return TRUE;
      }
    }
    return FALSE;
}

int Sg_CreateDirectory(SgString *path)
{
  return CreateDirectoryW(utf32ToUtf16(path), NULL);
}

#define DEFINE_FILE_STAD(name, prop)					\
  SgObject name(SgString *path)						\
  {									\
    DWORD flags = FILE_FLAG_BACKUP_SEMANTICS | FILE_ATTRIBUTE_NORMAL;	\
    HANDLE fd = CreateFileW(utf32ToUtf16(path), 0, 0, NULL, OPEN_EXISTING, \
			    flags, NULL);				\
    if (fd != INVALID_HANDLE_VALUE) {					\
      BY_HANDLE_FILE_INFORMATION fileInfo;				\
      if (GetFileInformationByHandle(fd, &fileInfo)) {			\
	int64_t tm;							\
	FILETIME *time;							\
	ULARGE_INTEGER li, adjust;					\
	CloseHandle(fd);						\
	time = &(fileInfo. SG_CPP_CAT3(ft, prop, Time));		\
	li.u.LowPart  = time->dwLowDateTime;				\
	li.u.HighPart = time->dwHighDateTime;				\
	adjust.QuadPart = 11644473600000 * 10000;			\
	tm = li.QuadPart - adjust.QuadPart;				\
	return Sg_MakeIntegerFromS64(tm * 100);				\
      }									\
      CloseHandle(fd);							\
    }									\
    return SG_UNDEF;							\
  }

DEFINE_FILE_STAD(Sg_FileModifyTime, LastWrite)
DEFINE_FILE_STAD(Sg_FileAccessTime, LastAccess)
DEFINE_FILE_STAD(Sg_FileChangeTime, Creation)

SgObject Sg_FileSize(SgString *path)
{
  HANDLE fd = CreateFileW(utf32ToUtf16(path), 
			  GENERIC_READ,
			  FILE_SHARE_READ | FILE_SHARE_WRITE,
			  NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
  if (fd != INVALID_HANDLE_VALUE) {
    LARGE_INTEGER bsize = {0};
    if (GetFileSizeEx(fd, &bsize)) {
      CloseHandle(fd);
      return Sg_MakeIntegerFromS64(bsize.QuadPart);
    }
    CloseHandle(fd);
  }
  return SG_UNDEF;
}

SgObject Sg_ReadDirectory(SgString *path)
{
  WIN32_FIND_DATAW data;
  HANDLE hdl;

  SgObject h = SG_NIL, t = SG_NIL;
  static const SgChar suf[] = { '\\', '*', 0 };
  const wchar_t *u16path
    = utf32ToUtf16(SG_STRING(Sg_StringAppendC(path, suf, 2)));

  hdl = FindFirstFileW(u16path, &data);
  if (hdl != INVALID_HANDLE_VALUE) {
    do {
      SG_APPEND1(h, t, utf16ToUtf32(data.cFileName));
    } while (FindNextFileW(hdl, &data));
    FindClose(hdl);
  } else {
    return SG_FALSE;
  }
  return h;
}

SgObject Sg_CurrentDirectory()
{
  wchar_t ucs2[MAX_PATH];
  if (!GetCurrentDirectoryW(MAX_PATH, ucs2)) {
    Sg_IOError(-1, SG_INTERN("current-directory"),
	       Sg_GetLastErrorMessage(), SG_FALSE, SG_FALSE);
    return SG_UNDEF;
  }
  return utf16ToUtf32(ucs2);
}

void Sg_SetCurrentDirectory(SgString *path)
{
  const wchar_t *ucs2 = utf32ToUtf16(path);
  if (!SetCurrentDirectoryW(ucs2)) {
    Sg_IOError(-1, SG_INTERN("set-current-directory"),
	       Sg_GetLastErrorMessage(), SG_FALSE, SG_FALSE);
  }
}

/* site dynload path is the same path as dynload path, so we don't make it */
static SgString *win_lib_path = NULL;
static SgString *win_sitelib_path = NULL;
static SgString *win_dynlib_path = NULL;

#define _U(s) SG_CPP_CAT(L, s)

#ifdef _SG_WIN_SUPPORT
/* somehow WATCOM does not work with swprintf_s. */
static void concat_w(wchar_t *buf, size_t n, wchar_t *a, wchar_t *b)
{
  int i;
  for (i = 0; i < n && *a; i++) {
    buf[i] = *a++;
  }
  for (; i < n && *b; i++) {
    buf[i] = *b++;
  }
}
#endif

static void initialize_path()
{
  wchar_t tmp[MAX_PATH];
  wchar_t path[MAX_PATH];
  if (GetModuleFileNameW(NULL, tmp, MAX_PATH)) {
    if (PathRemoveFileSpecW(tmp)) {
      static const wchar_t *fmt = L"%s%s";
      PathAddBackslashW(tmp);
      /* sitelib */
#if _MSC_VER
      swprintf_s(path, MAX_PATH, fmt, tmp, _U(SAGITTARIUS_SITE_LIB_PATH));
#else
      concat_w(path, MAX_PATH, tmp, _U(SAGITTARIUS_SITE_LIB_PATH));
#endif
      win_sitelib_path = utf16ToUtf32(path);
      /* lib */
#if _MSC_VER
      swprintf_s(path, MAX_PATH, fmt, tmp, _U(SAGITTARIUS_SHARE_LIB_PATH));
#else
      concat_w(path, MAX_PATH, tmp, _U(SAGITTARIUS_SHARE_LIB_PATH));
#endif
      win_lib_path = utf16ToUtf32(path);
      /* module */
#if _MSC_VER
      swprintf_s(path, MAX_PATH, fmt, tmp, _U(SAGITTARIUS_DYNLIB_PATH));
#else
      concat_w(path, MAX_PATH, tmp, _U(SAGITTARIUS_DYNLIB_PATH));
#endif
      win_dynlib_path = utf16ToUtf32(path);
      return;
    }
    goto recover;
  }
 recover:
  /* if above failed, we just use directory name as default load path. */
  /* TODO better solution */
  win_sitelib_path = SG_STRING(SG_MAKE_STRING(SAGITTARIUS_SITE_LIB_PATH));
  win_lib_path = SG_STRING(SG_MAKE_STRING(SAGITTARIUS_SHARE_LIB_PATH));
  win_dynlib_path = SG_STRING(SG_MAKE_STRING(SAGITTARIUS_DYNLIB_PATH));
}

SgObject Sg_InstalledDirectory()
{
  wchar_t tmp[MAX_PATH];
  if (GetModuleFileNameW(NULL, tmp, MAX_PATH)) {
    if (PathRemoveFileSpecW(tmp)) {
      PathAddBackslashW(tmp);
      return utf16ToUtf32(tmp);
    }
  }
  return SG_FALSE;
}

SgObject Sg_GetDefaultLoadPath()
{
  SgObject env = Sg_Getenv(UC("SAGITTARIUS_LOADPATH"));
  SgObject h = SG_NIL, t = SG_NIL;
  if (!SG_FALSEP(env) && SG_STRING_SIZE(env) != 0) {
    SG_APPEND(h, t, Sg_StringSplitChar(SG_STRING(env), ';'));
  }

  if (win_lib_path == NULL ||
      win_sitelib_path == NULL ||
      win_dynlib_path == NULL) {
    initialize_path();
  }
  SG_APPEND1(h, t, win_sitelib_path);
  SG_APPEND1(h, t, win_lib_path);
  return h;
}

SgObject Sg_GetDefaultDynamicLoadPath()
{
  SgObject env = Sg_Getenv(UC("SAGITTARIUS_DYN_LOADPATH"));
  SgObject h = SG_NIL, t = SG_NIL;

  if (!SG_FALSEP(env) && SG_STRING_SIZE(env) != 0) {
    SG_APPEND(h, t, Sg_StringSplitChar(SG_STRING(env), ';'));
  }

  /* this must be initialized when vm is being created. */
  if (win_lib_path == NULL ||
      win_sitelib_path == NULL ||
      win_dynlib_path == NULL) {
    initialize_path();
  }
  SG_APPEND1(h, t, win_dynlib_path);
  return h;
}

SgObject Sg_DirectoryName(SgString *path)
{
  int size = SG_STRING_SIZE(path), i;
  for (i = size-1; i >= 0; i--) {
    if (SG_STRING_VALUE_AT(path, i) == '\\') break;
  }
  if (i <= 0) return SG_FALSE;
  return Sg_Substring(path, 0, i);
}

SgObject Sg_BuildPath(SgString *path, SgString *file)
{
  int psize = SG_STRING_SIZE(path), fsize = SG_STRING_SIZE(file);
  int i, j, offset = 1;
  SgObject ret;
  if (SG_STRING_VALUE_AT(path, psize-1) == '\\') offset--;
  ret = Sg_ReserveString(psize + fsize + offset, 0);
  for (i = 0; i < psize; i++) {
    SG_STRING_VALUE_AT(ret, i) = SG_STRING_VALUE_AT(path, i);
  }
  if (offset) {
    SG_STRING_VALUE_AT(ret, i++) = '\\';
  }
  for (j = 0; j < fsize; i++, j++) {
    SG_STRING_VALUE_AT(ret, i) = SG_STRING_VALUE_AT(file, j);
  }
  return ret;
}

int Sg_AbsolutePathP(SgString *path)
{
  if (SG_STRING_VALUE_AT(path, 0) == '\\') return TRUE;
  else if (SG_STRING_SIZE(path) > 2 && 
	   isalpha(SG_STRING_VALUE_AT(path, 0)) &&
	   SG_STRING_VALUE_AT(path, 1) == ':') {
    return TRUE;
  }
  return FALSE;
}

SgObject Sg_AbsolutePath(SgString *path)
{
  wchar_t buf[MAX_PATH], *part;
  DWORD ret = GetFullPathNameW(utf32ToUtf16(path),
			       sizeof(buf)/sizeof(buf[0]),
			       buf,
			       &part);
  if (ret) {
    return SG_OBJ(utf16ToUtf32(buf));
  }
  return SG_FALSE;
}

int Sg_CopyAccessControl(SgString *src, SgString *dst)
{
  /* for now dummy */
  return TRUE;
}

SgObject Sg_SitelibPath()
{
  if (win_sitelib_path == NULL) initialize_path();
  return win_sitelib_path;
}

/*
  end of file
  Local Variables:
  coding: utf-8-unix
  End:
*/

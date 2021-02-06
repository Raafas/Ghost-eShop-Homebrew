/*
*   This file is part of Universal-Updater
*   Copyright (C) 2019-2020 Universal-Team
*
*   This program is free software: you can redistribute it and/or modify
*   it under the terms of the GNU General Public License as published by
*   the Free Software Foundation, either version 3 of the License, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU General Public License for more details.
*
*   You should have received a copy of the GNU General Public License
*   along with this program.  If not, see <http://www.gnu.org/licenses/>.
*
*   Additional Terms 7.b and 7.c of GPLv3 apply to this file:
*       * Requiring preservation of specified reasonable legal notices or
*         author attributions in that material or in the Appropriate Legal
*         Notices displayed by works containing it.
*       * Prohibiting misrepresentation of the origin of that material,
*         or requiring that modified versions of such material be marked in
*         reasonable ways as different from the original version.
*/

#include "files.hpp"

FS_Path getPathInfo(const char *path, FS_ArchiveID *archive) {
	*archive = ARCHIVE_SDMC;
	FS_Path filePath = { PATH_INVALID, 0, nullptr };
	unsigned int prefixlen = 0;

	if (!strncmp(path, "sdmc:/", 6)) {
		prefixlen = 5;

	} else if (*path != '/') {
		/*
			Si le chemin est local (ne pas commencer par une barre oblique),
			il doit être ajouté au répertoire de travail pour être valide.
		*/
		char *actualPath = NULL;
		asprintf(&actualPath, "%s%s", "/", path);
		filePath = fsMakePath(PATH_ASCII, actualPath);
		free(actualPath);
	}

	/* Si la valeur filePath est définie ci-dessus, définissez-la. */
	if (filePath.size == 0) filePath = fsMakePath(PATH_ASCII, path + prefixlen);

	return filePath;
}

Result makeDirs(const char *path) {
	Result ret = 0;
	FS_ArchiveID archiveID;
	FS_Path filePath = getPathInfo(path, &archiveID);
	FS_Archive archive;

	ret = FSUSER_OpenArchive(&archive, archiveID, fsMakePath(PATH_EMPTY, ""));

	for (char *slashpos = strchr(path + 1, '/'); slashpos != NULL; slashpos = strchr(slashpos + 1, '/')) {
		char bak = *(slashpos);
		*(slashpos) = '\0';
		Handle dirHandle;

		ret = FSUSER_OpenDirectory(&dirHandle, archive, filePath);
		if (R_SUCCEEDED(ret)) FSDIR_Close(dirHandle);
		else ret = FSUSER_CreateDirectory(archive, filePath, FS_ATTRIBUTE_DIRECTORY);

		*(slashpos) = bak;
	}

	FSUSER_CloseArchive(archive);

	return ret;
}

Result openFile(Handle *fileHandle, const char *path, bool write) {
	FS_ArchiveID archive;
	FS_Path filePath = getPathInfo(path, &archive);
	u32 flags = (write ? (FS_OPEN_CREATE | FS_OPEN_WRITE) : FS_OPEN_READ);

	Result ret = 0;
	ret = makeDirs(strdup(path));
	ret = FSUSER_OpenFileDirectly(fileHandle, archive, fsMakePath(PATH_EMPTY, ""), filePath, flags, 0);
	if (write)	ret = FSFILE_SetSize(*fileHandle, 0); // Tronquer le fichier pour supprimer le contenu précédent avant l’écriture.

	return ret;
}

Result deleteFile(const char *path) {
	FS_ArchiveID archiveID;
	FS_Path filePath = getPathInfo(path, &archiveID);

	FS_Archive archive;

	Result ret = FSUSER_OpenArchive(&archive, archiveID, fsMakePath(PATH_EMPTY, ""));
	if (R_FAILED(ret)) return ret;
	ret = FSUSER_DeleteFile(archive, filePath);
	FSUSER_CloseArchive(archive);

	return ret;
}

Result removeDir(const char *path) {
	FS_ArchiveID archiveID;
	FS_Path filePath = getPathInfo(path, &archiveID);
	FS_Archive archive;

	Result ret = FSUSER_OpenArchive(&archive, archiveID, fsMakePath(PATH_EMPTY, ""));
	if (R_FAILED(ret)) return ret;
	ret = FSUSER_DeleteDirectory(archive, filePath);
	FSUSER_CloseArchive(archive);

	return ret;
}

Result removeDirRecursive(const char *path) {
	FS_ArchiveID archiveID;
	FS_Path filePath = getPathInfo(path, &archiveID);
	FS_Archive archive;

	Result ret = FSUSER_OpenArchive(&archive, archiveID, fsMakePath(PATH_EMPTY, ""));
	if (R_FAILED(ret)) return ret;
	ret = FSUSER_DeleteDirectoryRecursively(archive, filePath);
	FSUSER_CloseArchive(archive);

	return ret;
}
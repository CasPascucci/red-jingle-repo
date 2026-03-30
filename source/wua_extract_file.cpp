#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include "zarchive/zarchivereader.h"

int main(int argc, char* argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: wua_extract_file <archive.wua> <relative/path> <output_file>\n";
        std::cerr << "Example: wua_extract_file game.wua meta/bootSound.btsnd out.btsnd\n";
        return 1;
    }

    ZArchiveReader* reader = ZArchiveReader::OpenFromFile(argv[1]);
    if (!reader) {
        std::cerr << "Failed to open: " << argv[1] << "\n";
        return 1;
    }

    // Find the title ID subfolder (e.g. 0005000e10102000_v32) automatically
    ZArchiveNodeHandle root = reader->LookUp("", false, true);
    ZArchiveNodeHandle titleDir = ZARCHIVE_INVALID_NODE;
    std::string titleDirName;

    uint32_t count = reader->GetDirEntryCount(root);
    for (uint32_t i = 0; i < count; i++) {
        ZArchiveReader::DirEntry entry;
        if (reader->GetDirEntry(root, i, entry) && entry.isDirectory) {
            titleDirName = entry.name;
            titleDir = reader->LookUp(titleDirName, false, true);
            break;
        }
    }

    if (titleDir == ZARCHIVE_INVALID_NODE) {
        std::cerr << "Could not find title directory in archive\n";
        delete reader;
        return 1;
    }

    // Build full internal path: titleId_vXX/meta/bootSound.btsnd
    std::string fullPath = titleDirName + "/" + argv[2];
    ZArchiveNodeHandle handle = reader->LookUp(fullPath, true, false);

    if (handle == ZARCHIVE_INVALID_NODE) {
        std::cerr << "File not found: " << fullPath << "\n";
        delete reader;
        return 1;
    }

    uint64_t fileSize = reader->GetFileSize(handle);
    std::vector<uint8_t> buffer(fileSize);
    reader->ReadFromFile(handle, 0, fileSize, buffer.data());

    std::ofstream out(argv[3], std::ios::binary);
    out.write(reinterpret_cast<char*>(buffer.data()), fileSize);

    std::cout << "Extracted " << fullPath << " (" << fileSize << " bytes) -> " << argv[3] << "\n";
    delete reader;
    return 0;
}

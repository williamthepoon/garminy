// Upload a file to GARMIN/Apps on the first connected MTP device.
// Usage: mtpput <local-file> <remote-name>
import Foundation

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(("error: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: mtpput <local-file> <remote-name>\n".data(using: .utf8)!)
    exit(2)
}
let localPath = args[1], remoteName = args[2]
guard let attrs = try? FileManager.default.attributesOfItem(atPath: localPath),
      let size = (attrs[.size] as? NSNumber)?.uint64Value else {
    fail("cannot read \(localPath)")
}

LIBMTP_Init()
guard let dev = LIBMTP_Get_First_Device() else {
    fail("no watch found over MTP. Plug it in with a data cable (not via a hub) and quit Garmin Express.")
}
defer { LIBMTP_Release_Device(dev) }

if let m = LIBMTP_Get_Modelname(dev) {
    let model = String(cString: m)
    free(m)
    print("Connected: \(model)")
    if !model.lowercased().contains("fenix 7") {
        print("warning: garminy is built for the fēnix 7; this device reports \"\(model)\"")
    }
}

// Find GARMIN/Apps (case-insensitive) on any storage.
func child(_ first: UnsafeMutablePointer<LIBMTP_folder_t>?, named name: String) -> UnsafeMutablePointer<LIBMTP_folder_t>? {
    var f = first
    while let cur = f {
        if let n = cur.pointee.name, String(cString: n).caseInsensitiveCompare(name) == .orderedSame { return cur }
        f = cur.pointee.sibling
    }
    return nil
}

_ = LIBMTP_Get_Storage(dev, Int32(LIBMTP_STORAGE_SORTBY_NOTSORTED))
var target: (folder: UInt32, storage: UInt32)?
var storage = dev.pointee.storage
while let s = storage, target == nil {
    if let tree = LIBMTP_Get_Folder_List_For_Storage(dev, s.pointee.id) {
        if let garmin = child(tree, named: "GARMIN"), let apps = child(garmin.pointee.child, named: "Apps") {
            target = (apps.pointee.folder_id, s.pointee.id)
        }
        LIBMTP_destroy_folder_t(tree)
    }
    storage = s.pointee.next
}
guard let (folderId, storageId) = target else { fail("GARMIN/Apps folder not found on the device") }

// Replace any existing file with the same name.
var existing = LIBMTP_Get_Files_And_Folders(dev, storageId, folderId)
while let e = existing {
    if let n = e.pointee.filename, String(cString: n).caseInsensitiveCompare(remoteName) == .orderedSame {
        if LIBMTP_Delete_Object(dev, e.pointee.item_id) != 0 { fail("could not remove the old \(remoteName)") }
        print("Removed old \(remoteName)")
    }
    let next = e.pointee.next
    LIBMTP_destroy_file_t(e)
    existing = next
}

let file = LIBMTP_new_file_t()!
defer { LIBMTP_destroy_file_t(file) }
file.pointee.filename = strdup(remoteName)
file.pointee.filesize = size
file.pointee.filetype = LIBMTP_FILETYPE_UNKNOWN
file.pointee.parent_id = folderId
file.pointee.storage_id = storageId
if LIBMTP_Send_File_From_File(dev, localPath, file, nil, nil) != 0 {
    LIBMTP_Dump_Errorstack(dev)
    fail("upload failed")
}

// Confirm by reading the metadata back.
guard let meta = LIBMTP_Get_Filemetadata(dev, file.pointee.item_id) else { fail("uploaded, but could not confirm") }
defer { LIBMTP_destroy_file_t(meta) }
guard meta.pointee.filesize == size else {
    fail("size mismatch: sent \(size) bytes, watch reports \(meta.pointee.filesize)")
}
print("Uploaded GARMIN/Apps/\(remoteName) (\(size) bytes). Unplug the watch to install.")

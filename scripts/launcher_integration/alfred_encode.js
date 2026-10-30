// Pure JXA encoding: no Application(), ObjC imports, automation or filesystem I/O.
function run(argv) {
    if (argv.length !== 1 || argv[0].indexOf("FileMint-QA") !== 0 || argv[0].length > 1024) {
        throw new Error("Use one documented FileMint-QA synthetic sample.");
    }
    // Encode RFC 3986 query-value characters, including encodeURIComponent's five exceptions.
    var encoded = encodeURIComponent(argv[0]).replace(/[!'()*]/g, function (character) {
        return "%" + character.charCodeAt(0).toString(16).toUpperCase();
    });
    return "filemint-launcher-qa://draft?v=1&probe=filemint-p0&id=fbe0125f-01c2-4d32-9ec8-5fc586680e56&name="
        + encoded + "&text=QA%20synthetic%20body";
}

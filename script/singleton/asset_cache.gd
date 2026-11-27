extends Node

const CACHE_ROOT = "user://cache/"
const MANIFEST_PATH = "user://cache/manifest.json"
const CACHE_VERSION = 1

func cache_directory():
	return CACHE_ROOT

func resolve_cached_path(relative_path):
	return CACHE_ROOT + relative_path

func has_cached_file(relative_path):
	return FileAccess.file_exists(resolve_cached_path(relative_path))

func ensure_cache_directory():
	if not DirAccess.dir_exists_absolute(CACHE_ROOT):
		DirAccess.make_dir_recursive_absolute(CACHE_ROOT)

func load_manifest():
	if not FileAccess.file_exists(MANIFEST_PATH):
		return null
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed

func save_manifest(generated_files):
	ensure_cache_directory()
	var payload = {
		version = CACHE_VERSION,
		generated_files = generated_files
	}
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))

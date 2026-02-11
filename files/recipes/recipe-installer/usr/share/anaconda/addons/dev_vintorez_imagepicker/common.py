import json
import os
import platform
import shutil
from typing import TypedDict

from schema_validator import Optional, Schema, String

OS_RELEASE_PATH = "/etc/os-release"
CONTAINER_POLICY_PATH = "/etc/containers/policy.json"
IMAGE_LIST_PATH = "/etc/{os_id}/images.json"
SIGNING_KEY_DEFAULT_PATH = "/etc/{os_id}/signing_key.pub"
SIGNING_KEY_DIR_PATH = "/etc/pki/containers/"

class ImagePickerException(Exception):
	"""
	Custom exception to make it clear an error came from this addon.
	"""
	pass

# Anaconda is limited to Python 3.10 so use inheritance pattern with total=False to allow optional description
class _Image(TypedDict):
	id: str
	pretty_name: str
	uri: str
class Image(_Image, total=False):
	description: str | None

ImageJsonSchema = Schema([{
	"id": String(regex=r"^[a-z_][a-z0-9_-]*$"),
	"pretty_name": str,
	"uri": String(regex=r"^(([a-z0-9]|[a-z0-9][a-z0-9\\-]*[a-z0-9])\\.)*([a-z0-9]|[a-z0-9][a-z0-9\\-]*[a-z0-9])(:[0-9]+\\/)?(?:[0-9a-z-]+[/@])(?:([0-9a-z-]+))[/@]?(?:([0-9a-z-]+))?(?::[a-z0-9\\.-]+)?$"),
	"description": Optional(str)
}])

def get_os_release_id() -> str:
	"""
	Loads and parses /etc/os-release to find the ID.
	Raises ImagePickerException if file is missing or ID is not found.
	"""
	if not os.path.exists(OS_RELEASE_PATH):
		raise ImagePickerException(f"Critical Error: {OS_RELEASE_PATH} is missing.")

	try:
		return platform.freedesktop_os_release()['ID']
	except OSError as e:
		raise ImagePickerException(f"Critical Error: Failed to read {OS_RELEASE_PATH}: {e}")

def get_image_list(os_id: str) -> list[Image]:
	"""
	Loads and parses /etc/{os_id}/images.json to get a list of allowed images.
	Returns a tuple of the Image dict.
	Raises ImagePickerException if the file is missing or couldn't be parsed.
	"""
	path = IMAGE_LIST_PATH.format(os_id=os_id)

	if not os.path.exists(path):
		raise ImagePickerException(f"Critical Error: {path} is missing.")

	try:
		with open(path, "r") as f:
			images = json.load(f)
	except OSError as e:
		raise ImagePickerException(f"Critical Error: Failed to read {path}: {e}")

	try:
		return ImageJsonSchema.validate(images)
	except ValueError as e:
		raise ImagePickerException(f"Critical Error: Failed to validate {path}: {e}")

def validate_picked_image(image_uri: str, images: list[Image]) -> bool:
	"""
	Checks if the selected image uri is in the list of images
	Returns True if valid image
	"""
	for img in images:
		if img.get('uri') == image_uri:
			return True
	return False

def install_image_signing_key(os_id: str, repo_url: str, key_path: str) -> None:
	"""
	Installs the signing key, and modifies the /etc/containers/policy.json signing policy file
	Raises ImagePickerException if the key installation fails.
	"""
	if not repo_url:
		raise ImagePickerException("Critical Error: Repository URL is missing.")

	if not os.path.exists(key_path):
		raise ImagePickerException(f"Critical Error: Signing key not found at {key_path}.")

	dest_key_path = os.path.join(SIGNING_KEY_DIR_PATH, f"{os_id}.pub")

	try:
		os.makedirs(SIGNING_KEY_DIR_PATH, exist_ok=True)
		shutil.copy(key_path, dest_key_path)
	except OSError as e:
		raise ImagePickerException(f"Critical Error: Failed to copy signing key to {dest_key_path}: {e}")

	try:
		repo = repo_url.split(":")[0] if ":" in repo_url else repo_url

		if os.path.exists(CONTAINER_POLICY_PATH):
			with open(CONTAINER_POLICY_PATH, "r") as f:
				policy = json.load(f)
		else:
			raise ImagePickerException(f"Critical Error: Container policy file not found at {CONTAINER_POLICY_PATH}")

		if "transports" not in policy:
			policy["transports"] = {}
		if "docker" not in policy["transports"]:
			policy["transports"]["docker"] = {}

		policy["transports"]["docker"][repo] = [
			{
				"type": "sigstoreSigned",
				"keyPath": dest_key_path,
				"signedIdentity": {
					"type": "matchRepository"
				}
			}
		]

		with open(CONTAINER_POLICY_PATH, "w") as f:
			json.dump(policy, f, indent=4)

	except (OSError, json.JSONDecodeError) as e:
		raise ImagePickerException(f"Critical Error: Failed to update container policy at {CONTAINER_POLICY_PATH}: {e}")

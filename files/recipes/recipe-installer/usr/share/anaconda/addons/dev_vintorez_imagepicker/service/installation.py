from dev_vintorez_imagepicker.common import get_os_release_id, install_image_signing_key
from pyanaconda.modules.common.task import Task


class ConfigureKeyTask(Task):
    def __init__(self, selected_image_uri):
        super().__init__()
        self._image_uri = selected_image_uri

    @property
    def name(self):
        return "Configure Image Signing Key"

    def run(self):
        # This code runs ONLY when installation begins.
        if not self._image_uri:
            return

        os_id = get_os_release_id()
        # Logic to determine repo_url and key_path from the uri
        # You might need to reuse your get_image_list logic or pass specific paths
        # if they aren't directly derivable from the URI alone.
        # For this example, assuming you can derive them or passed them in:

        # Example placeholder logic:
        # repo_url = derive_repo_url(self._image_uri)
        # key_path = derive_key_path(self._image_uri)

        # install_image_signing_key(os_id, repo_url, key_path)
        pass

from dev_vintorez_imagepicker.common import get_image_list, get_os_release_id
from dev_vintorez_imagepicker.constants import IMAGE_PICKER
from dev_vintorez_imagepicker.service.installation import ConfigureKeyTask
from dev_vintorez_imagepicker.service.interface import ImagePickerInterface
from dev_vintorez_imagepicker.service.kickstart import ImagePickerKickstartSpecification
from pyanaconda.core.dbus import DBus
from pyanaconda.modules.common.base import KickstartService
from pyanaconda.modules.common.containers import TaskContainer


class ImagePickerService(KickstartService):
    def __init__(self):
        super().__init__()
        self._selected_image = ""
        self._os_id = get_os_release_id()

    def publish(self):
        TaskContainer.set_namespace(IMAGE_PICKER.namespace)
        DBus.publish_object(IMAGE_PICKER.object_path, ImagePickerInterface(self))
        DBus.register_service(IMAGE_PICKER.service_name)

    @property
    def kickstart_specification(self):
        return ImagePickerKickstartSpecification

    # --- Methods for Interface ---
    def set_selected_image(self, uri):
        # Only update the variable. Do NOT install the key here.
        self._selected_image = uri

    def get_available_images(self):
        images = get_image_list(self._os_id)
        return [(img['id'], img['pretty_name'], img['uri']) for img in images]

    # --- Anaconda Hooks ---
    def install_with_tasks(self):
        """Called when user clicks Begin Installation."""
        tasks = []
        if self._selected_image:
            # Generate the task to install the key now
            tasks.append(ConfigureKeyTask(self._selected_image))
        return tasks

    def setup_kickstart(self, data):
        """Apply selection to Kickstart data (ksdata)."""
        if self._selected_image:
            data.ostreecontainer.url = self._selected_image

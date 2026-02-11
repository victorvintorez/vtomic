from dasbus.server.interface import dbus_interface
from dasbus.typing import *
from dev_vintorez_imagepicker.constants import IMAGE_PICKER
from pyanaconda.modules.common.base import KickstartModuleInterface


@dbus_interface(IMAGE_PICKER.interface_name)
class ImagePickerInterface(KickstartModuleInterface):
    @property
    def SelectedImage(self) -> Str:
        return self.implementation._selected_image

    def SetSelectedImage(self, uri: Str):
        self.implementation.set_selected_image(uri)

    def GetImageList(self) -> List[Tuple[Str, Str, Str]]:
        return self.implementation.get_available_images()

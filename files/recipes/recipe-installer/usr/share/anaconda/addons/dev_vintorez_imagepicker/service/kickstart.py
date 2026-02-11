from pyanaconda.core.kickstart import KickstartSpecification
from pyanaconda.core.kickstart.addon import AddonData


class ImagePickerData(AddonData):
    def __init__(self):
        super().__init__()
        self.selected_image = ""
        # ... handle_header / handle_line ...

class ImagePickerKickstartSpecification(KickstartSpecification):
    addons = {
        "dev_vintorez_imagepicker": ImagePickerData
    }

from pyanaconda.ui.gui.spokes import NormalSpoke

from dev_vintorez_imagepicker.constants import IMAGE_PICKER


class ImagePickerSpoke(NormalSpoke):
    # ... configuration (ui file, title, etc) ...

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._service_proxy = IMAGE_PICKER.get_proxy()

    def initialize(self):
        super().initialize()
        # Fetch data via D-Bus
        try:
            images = self._service_proxy.GetImageList()
            # ... populate your GTK ListStore with 'images' ...
        except Exception as e:
            # Handle D-Bus errors
            pass

    def apply(self):
        # 1. Get selection from UI
        selected_uri = ...

        # 2. Send to Service (Does NOT install key yet)
        self._service_proxy.SetSelectedImage(selected_uri)

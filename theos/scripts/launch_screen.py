import plistlib

LAUNCH_SCREEN_NAME = 'LaunchScreen'


class _KeyedArchive:
    def __init__(self):
        self.objects = ['$null']
        self.classes = {}

    def _append(self, value):
        self.objects.append(value)
        return plistlib.UID(len(self.objects) - 1)

    def _class(self, hierarchy):
        name = hierarchy[0]
        if name not in self.classes:
            self.classes[name] = self._append({'$classname': name, '$classes': list(hierarchy)})
        return self.classes[name]

    def string(self, value):
        return self._append(value)

    def array(self, items):
        return self._append({'$class': self._class(('NSArray', 'NSObject')), 'NS.objects': list(items)})

    def instance(self, hierarchy, fields):
        payload = dict(fields)
        payload['$class'] = self._class(hierarchy)
        return self._append(payload)

    def encode(self, top):
        return plistlib.dumps({'$version': 100000, '$archiver': 'NSKeyedArchiver', '$top': top, '$objects': self.objects},
                              fmt=plistlib.FMT_BINARY, sort_keys=False)


def launch_screen_nib(red=1.0, green=1.0, blue=1.0):
    archive = _KeyedArchive()
    color = archive.instance(('UIColor', 'NSObject'), {
        'UIColorComponentCount': 4,
        'UIRed': float(red),
        'UIGreen': float(green),
        'UIBlue': float(blue),
        'UIAlpha': 1.0,
        'NSColorSpace': 2,
        'NSRGB': ('%g %g %g' % (red, green, blue)).encode('ascii') + b'\0',
    })
    view = archive.instance(('UIView', 'UIResponder', 'NSObject'), {
        'UIBounds': archive.string('{{0, 0}, {320, 480}}'),
        'UICenter': archive.string('{160, 240}'),
        'UIBackgroundColor': color,
        'UIAutoresizingMask': 18,
        'UIAutoresizeSubviews': True,
        'UIOpaque': True,
        'UIClearsContextBeforeDrawing': True,
    })
    objects = archive.array([view])
    empty = archive.array([])
    return archive.encode({
        'UINibAccessibilityConfigurationsKey': empty,
        'UINibConnectionsKey': empty,
        'UINibKeyValuePairsKey': empty,
        'UINibObjectsKey': objects,
        'UINibTopLevelObjectsKey': objects,
        'UINibVisibleWindowsKey': empty,
    })

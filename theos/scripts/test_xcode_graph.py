#!/usr/bin/env python3
import tempfile
import unittest
from pathlib import Path
from xcode_graph import parse, parse_text, xcconfig

class ParserTests(unittest.TestCase):
    def test_localization_unicode_and_last_assignment(self):
        self.assertEqual(parse_text(r'{ "key" = "old"; "key" = "\U0410\n\UD83D\UDE00"; }',allow_duplicates=True),{'key':'А\n😀'})

    def test_openstep_strings_comments_and_nested_arrays(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'project.pbxproj'
            path.write_text(r'''// !$*UTF8*$!
            { objects = { ABC /* comment */ = { isa = PBXBuildFile;
                settings = { COMPILER_FLAGS = "-fno-objc-arc -DNAME=\"hello world\""; };
                files = (A, B,); "OTHER_CFLAGS[arch=*]" = ("-Xclang", "-fobjc-runtime-has-weak");
                shellScript = "echo hi\n"; }; }; }''')
            obj=parse(path)['objects']['ABC']
            self.assertEqual(obj['settings']['COMPILER_FLAGS'],'-fno-objc-arc -DNAME="hello world"')
            self.assertEqual(obj['files'],['A','B'])
            self.assertEqual(obj['shellScript'],'echo hi\n')
            self.assertEqual(obj['OTHER_CFLAGS[arch=*]'],['-Xclang','-fobjc-runtime-has-weak'])

    def test_config_inherits_across_include_and_project_layers(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            (root/'Common.xcconfig').write_text('FLAGS = $(inherited) common\n')
            (root/'Target.xcconfig').write_text('#include "Common.xcconfig"\nFLAGS = $(inherited) target\n')
            self.assertEqual(xcconfig(root/'Target.xcconfig',{'FLAGS':'project'})['FLAGS'],'project common target')

    def test_rejects_duplicate_keys(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'bad.pbxproj'
            path.write_text('{ key = one; key = two; }')
            with self.assertRaises(AssertionError):parse(path)

if __name__=='__main__':unittest.main()

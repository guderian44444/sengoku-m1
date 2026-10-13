#!/usr/bin/env python3
"""Numerical and sampling regressions for the analysis-only color audit."""
from pathlib import Path
import importlib.util
import unittest
import numpy as np
from PIL import Image

spec=importlib.util.spec_from_file_location('colors',Path(__file__).with_name('audit-oichi-colors-v27.py'))
colors=importlib.util.module_from_spec(spec);spec.loader.exec_module(colors)


class ColorTests(unittest.TestCase):
    def test_standard_srgb_lab_values(self):
        actual=colors.srgb_to_lab(np.array([[0,0,0],[255,255,255],[255,0,0]]))
        expected=np.array([[0,0,0],[100,0,0],[53.2408,80.0925,67.2032]])
        np.testing.assert_allclose(actual,expected,atol=.001)

    def test_hidden_rgb_and_edges_excluded(self):
        data=np.full((24,24,4),[216,154,109,255],dtype='uint8')
        data[:8,:,3]=0
        data[8:16,:,3]=245
        masks,stats,_=colors.analyze(Image.fromarray(data),minimum=1)
        self.assertEqual(stats['skin']['samples'],8*24)
        self.assertFalse(masks['skin'][:16].any())

    def test_same_material_self_comparison(self):
        data=np.full((24,24,4),[216,154,109,255],dtype='uint8')
        _,stats,_=colors.analyze(Image.fromarray(data),minimum=1)
        diff=colors.differences(stats['skin'],stats['skin'])
        self.assertEqual(diff['status'],'within_diagnostic_limits')
        self.assertEqual(diff['deltas']['median_L'],0)

    def test_known_bright_skin_detected(self):
        original=np.full((24,24,4),[216,154,109,255],dtype='uint8')
        bright=np.full((24,24,4),[253,192,150,255],dtype='uint8')
        _,a,_=colors.analyze(Image.fromarray(original),minimum=1)
        _,b,_=colors.analyze(Image.fromarray(bright),minimum=1)
        diff=colors.differences(b['skin'],a['skin'])
        self.assertIn('median_L',diff['flags'])
        self.assertGreater(diff['deltas']['median_L'],10)

    def test_missing_material_not_pass(self):
        im=Image.new('RGBA',(20,20))
        _,stats,_=colors.analyze(im)
        self.assertEqual(colors.differences(stats['skin'],stats['skin'])['status'],'review_sampling')

    def test_detached_red_details_not_skirt(self):
        data=np.zeros((160,160,4),dtype='uint8')
        data[50:110,55:115]=[130,35,30,255]
        data[140:145,60:67]=[130,35,30,255]
        masks,_,_=colors.analyze(Image.fromarray(data),minimum=1)
        self.assertTrue(masks['red_skirt'][65,65])
        self.assertFalse(masks['red_skirt'][142,63])

    def test_foreign_figure_exclusion_is_analysis_only(self):
        data=np.full((24,24,4),[216,154,109,255],dtype='uint8')
        eligible=np.zeros((24,24),dtype=bool);eligible[:,12:]=True
        im=Image.fromarray(data);before=im.tobytes()
        masks,stats,_=colors.analyze(im,minimum=1,eligible=eligible)
        self.assertEqual(stats['skin']['samples'],24*12)
        self.assertFalse(masks['skin'][:,:12].any())
        self.assertEqual(before,im.tobytes())


if __name__=='__main__':unittest.main(verbosity=2)

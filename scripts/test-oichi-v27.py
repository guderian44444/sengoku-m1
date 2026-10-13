#!/usr/bin/env python3
"""Builder regressions and optional original-approved production validation."""
from pathlib import Path
import argparse
import copy
import importlib.util
import json
import tempfile
import unittest

import numpy as np
from PIL import Image, ImageDraw

MODULE = Path(__file__).with_name('register-oichi-v27.py')
spec = importlib.util.spec_from_file_location('oichi_v27', MODULE)
registration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(registration)


class BuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.folder = Path(cls.temp.name)
        cls.poses = registration.template(cls.folder)
        cls.poses['provenance'] = {'kind':'synthetic-test-fixture', 'sources':{},
                                   'note':'Temporary rectangles only; no production art or grading acceptance.'}
        cls.poses['portrait']['rect'] = [145,85,90,100]
        # Deliberately non-anatomical test rectangles, never production artwork.
        for name in registration.CLIPS:
            image = Image.new('RGBA',(1536,1024))
            draw = ImageDraw.Draw(image)
            entry = cls.poses['clips'][name]
            entry['body_height'] = 440
            entry['anatomical_measurement'] = 'Synthetic validation fixture; explicit independent 440 px ruler.'
            for index, frame in enumerate(entry['frames']):
                x, y = (index%3)*512, (index//3)*512
                draw.rectangle((x+140,y+80,x+300+index,y+420), fill=(180+index,40,30,255))
                # Preserve separated translucent details instead of selecting
                # only the largest connected component.
                draw.rectangle((x+115,y+100,x+118,y+108), fill=(20,20,20,37))
                frame.update(foot=[x+220,y+422], hand=[x+270,y+200], weapon_angle=0)
                if name in registration.FRONT_BOW:
                    frame['hand_occluders'] = [[x+263,y+193,14,14]]
            image.save(cls.folder/(name+'.png'))
            entry['source_sha256'] = registration.sha((cls.folder/(name+'.png')).read_bytes())
        cls.valid = registration.build(cls.folder,cls.poses)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_full_set_and_alias_contract(self):
        self.assertEqual(len(self.valid['clips']),26)
        self.assertEqual(sum(len(c['frames']) for c in self.valid['clips'].values()),156)
        self.assertEqual(self.valid['aliases'],registration.ALIASES)

    def test_original_production_and_provenance_retained(self):
        self.assertEqual(self.valid['production_id'],registration.PRODUCTION_ID)
        self.assertEqual(self.valid['provenance'],self.poses['provenance'])
        self.assertIsNot(self.valid['provenance'],self.poses['provenance'])
        self.assertIsNot(self.valid['provenance']['sources'],self.poses['provenance']['sources'])

    def test_missing_or_wrong_production_rejected(self):
        for value in [None,'rejected-earlier-v27']:
            poses=copy.deepcopy(self.poses)
            poses['production_id']=value
            with self.assertRaisesRegex(ValueError,'production_id'):
                registration.build(self.folder,poses)

    def test_missing_or_invalid_provenance_rejected(self):
        for value in [None,[], 'unverified']:
            poses=copy.deepcopy(self.poses)
            poses['provenance']=value
            with self.assertRaisesRegex(ValueError,'provenance dictionary'):
                registration.build(self.folder,poses)

    def test_small_canonical_source_rejected(self):
        path=self.folder/'small-sheet.png'
        Image.new('RGBA',(1000,900)).save(path)
        with self.assertRaisesRegex(ValueError,'canonical source pixels'):
            registration.native_image(path,sheet=True)

    def test_non_grid_1774_by_887_source_with_explicit_regions(self):
        poses=copy.deepcopy(self.poses)
        path=self.folder/'launched.png'
        original=path.read_bytes()
        try:
            image=Image.new('RGBA',(1774,887))
            draw=ImageDraw.Draw(image)
            entry=poses['clips']['launched']
            for index,frame in enumerate(entry['frames']):
                x,y=(index%3)*591,(index//3)*443
                w,h=(592 if index%3==2 else 591),(444 if index//3 else 443)
                draw.rectangle((x+120,y+60,x+320+index,y+370),fill=(170+index,40,30,255))
                frame.update(source_region=[x,y,w,h],foot=[x+220,y+390],hand=[x+270,y+200],body_height=340)
            image.save(path)
            entry['source_sha256']=registration.sha(path.read_bytes())
            result=registration.build(self.folder,poses)
            self.assertEqual(result['clips']['launched']['source_size'],[1774,887])
            self.assertEqual(len(result['clips']['launched']['frames']),6)
            _,_,measured=registration.inspect_sheet(path,entry['frames'])
            self.assertEqual(measured[0]['nominal_cell'],None)
            self.assertEqual(measured[0]['cell'],[0,0,591,443])
            self.assertEqual(registration.template(self.folder)['clips']['launched']['source_sha256'],entry['source_sha256'])
            self.assertEqual(registration.measure_sources(self.folder,poses)['launched']['source_size'],[1774,887])
            del entry['frames'][0]['source_region']
            with self.assertRaisesRegex(ValueError,'exact 3 x 2 cells'):
                registration.build(self.folder,poses)
            with self.assertRaisesRegex(ValueError,'explicit source_region'):
                registration.inspect_sheet(path)
        finally:
            path.write_bytes(original)

    def test_independent_anatomy_and_virtual_support(self):
        frame = self.valid['clips']['idle']['frames'][0]
        self.assertEqual(frame['body_height'],440)
        self.assertNotEqual(frame['body_height'],frame['rect'][3])
        self.assertLess(frame['foot'][1],frame['rect'][3])

    def test_all_alpha_pixels_retained(self):
        image = Image.open(self.folder/'idle.png')
        for frame in self.valid['clips']['idle']['frames']:
            x,y,w,h = frame['rect']
            cx,cy,cw,ch = frame['source_cell']
            crop = np.asarray(image)[y:y+h,x:x+w]
            cell = np.asarray(image)[cy:cy+ch,cx:cx+cw]
            self.assertEqual(np.count_nonzero(crop[:,:,3]),np.count_nonzero(cell[:,:,3]))
            self.assertEqual(registration.sha(crop.tobytes()),frame['rgba_sha256'])

    def test_incomplete_set_rejected(self):
        poses = copy.deepcopy(self.poses)
        del poses['clips']['guard']
        with self.assertRaisesRegex(ValueError,'26'):
            registration.build(self.folder,poses)

    def test_unmeasured_anatomy_rejected(self):
        poses = copy.deepcopy(self.poses)
        poses['clips']['idle']['body_height'] = None
        with self.assertRaisesRegex(ValueError,'anatomical body_height'):
            registration.build(self.folder,poses)

    def test_transparent_grip_rejected(self):
        poses = copy.deepcopy(self.poses)
        poses['clips']['idle']['frames'][0]['hand'] = [50,50]
        with self.assertRaisesRegex(ValueError,'drawn body'):
            registration.build(self.folder,poses)

    def test_front_hand_occlusion_required(self):
        poses = copy.deepcopy(self.poses)
        poses['clips']['heavy1']['frames'][0]['hand_occluders'] = []
        with self.assertRaisesRegex(ValueError,'hand_occluders'):
            registration.build(self.folder,poses)

    def test_cell_edge_art_rejected_without_mutation(self):
        path = self.folder/'edge-case.png'
        image = Image.open(self.folder/'idle.png')
        image.putpixel((511,200),(1,2,3,255))
        image.save(path)
        before = path.read_bytes()
        with self.assertRaisesRegex(ValueError,'cell edge'):
            registration.inspect_sheet(path)
        self.assertEqual(path.read_bytes(),before)

    def test_single_native_frame_override(self):
        poses=copy.deepcopy(self.poses)
        image=Image.new('RGBA',(780,360))
        ImageDraw.Draw(image).rectangle((30,90,749,269),fill=(120,80,55,255))
        path=self.folder/'down-final.png';image.save(path)
        frame=poses['clips']['down']['frames'][5]
        frame.update(file=path.name,source_sha256=registration.sha(path.read_bytes()),source_region=[0,0,780,360],
                     foot=[400,271],hand=[390,170],body_height=800)
        result=registration.build(self.folder,poses)
        self.assertEqual(len(result['clips']['down']['frames']),6)
        self.assertEqual(result['clips']['down']['frames'][5]['file'],'down-final.png')
        self.assertEqual(result['sources']['down-final.png']['size'],[780,360])
        measured=registration.measure_sources(self.folder,poses)
        self.assertEqual(measured['down']['frames'][5]['source_file'],'down-final.png')
        self.assertEqual(measured['down']['frames'][5]['source_size'],[780,360])

    def test_stale_anchor_source_hash_rejected(self):
        poses=copy.deepcopy(self.poses)
        poses['clips']['idle']['source_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'exact source SHA256'):
            registration.build(self.folder,poses)

    def test_near_transparent_haze_does_not_silently_pass(self):
        path=self.folder/'haze-case.png'
        image=Image.new('RGBA',(1536,1024),(120,80,50,8))
        ImageDraw.Draw(image).rectangle((140,80,300,420),fill=(180,40,30,255))
        image.save(path);before=path.read_bytes()
        with self.assertRaisesRegex(ValueError,'genuine transparent background'):
            registration.native_image(path)
        self.assertEqual(path.read_bytes(),before)
        self.assertEqual(registration.alpha_diagnostics(np.asarray(image.getchannel('A')))['exact_zero_fraction'],0)

    def test_occluder_native_transparent_padding_retained(self):
        poses=copy.deepcopy(self.poses)
        poses['clips']['heavy1']['frames'][0]['hand_occluders']=[[290,190,20,20]]
        result=registration.build(self.folder,poses)
        x,_,w,_=result['clips']['heavy1']['frames'][0]['rect']
        self.assertGreaterEqual(x+w,310)

    def test_three_figure_component_isolation_preserves_source(self):
        image=Image.new('RGBA',(1536,1024));draw=ImageDraw.Draw(image)
        for i in range(3):draw.rectangle((i*512+80,100,i*512+420,900),fill=(170+i,40,30,255))
        before=image.tobytes();alpha=np.asarray(image.getchannel('A'))
        polygon=registration.isolation_polygon(image,alpha,[0,0,1536,1024],1,3)
        mask=Image.new('L',image.size);ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon],fill=1)
        own=(np.asarray(mask)>0)&(alpha>32)
        self.assertTrue(own[500,700]);self.assertFalse(own[500,200]);self.assertFalse(own[500,1200])
        self.assertEqual(image.tobytes(),before)

    def test_split_three_plus_three_native_run(self):
        poses=copy.deepcopy(self.poses);entry=poses['clips']['run'];original=(self.folder/'run.png').read_bytes()
        try:
            for half,file in enumerate(['run.png','run-opposite.png']):
                image=Image.new('RGBA',(1536,1024));draw=ImageDraw.Draw(image)
                for i in range(3):draw.rectangle((i*512+80,100,i*512+420,900),fill=(170+half*3+i,40,30,255))
                path=self.folder/file;image.save(path);digest=registration.sha(path.read_bytes())
                if half==0:entry['source_sha256']=digest
                for i in range(3):
                    frame=entry['frames'][half*3+i]
                    frame.update(source_region=[i*512,0,512,1024],foot=[i*512+220,902],hand=[i*512+270,500],body_height=800)
                    if half:frame.update(file=file,source_sha256=digest)
            result=registration.build(self.folder,poses)
            self.assertEqual(len(result['clips']['run']['frames']),6)
            self.assertEqual(result['clips']['run']['frames'][3]['file'],'run-opposite.png')
        finally:(self.folder/'run.png').write_bytes(original)

    def test_shared_transition_is_explicit_without_duplicate_clip_frames(self):
        poses=copy.deepcopy(self.poses)
        path=self.folder/'shared-prone.png'
        image=Image.new('RGBA',(780,361));ImageDraw.Draw(image).rectangle((30,90,749,269),fill=(126,80,55,255));image.save(path)
        frame={'file':path.name,'source_sha256':registration.sha(path.read_bytes()),'source_region':[0,0,780,361],
               'foot':[400,271],'hand':[390,170],'body_height':800,'weapon_angle':-90,'weapon_behind':True,'weapon_visible':True}
        poses['clips']['down']['frames'][5]=copy.deepcopy(frame)
        poses['clips']['recovering']['frames'][0]=copy.deepcopy(frame)
        result=registration.build(self.folder,poses)
        self.assertEqual(result['registered_frame_count'],156)
        pair=[g for g in result['shared_drawn_poses'] if g['source_file']==path.name]
        self.assertEqual(pair[0]['frames'],['down/6','recovering/1'])
        for name in ['down','recovering']:
            self.assertEqual(len({f['rgba_sha256'] for f in result['clips'][name]['frames']}),6)


def verify_final():
    folder = registration.ASSETS
    poses = json.loads((folder/'pose-anchors.json').read_text())
    actual = json.loads((folder/'registration.json').read_text())
    rebuilt = registration.build(folder,poses)
    assert actual == rebuilt, 'Final registration drift'
    assert actual['production_id'] == registration.PRODUCTION_ID, 'Wrong Oichi production identity'
    assert actual['provenance'] == poses['provenance'] and actual['provenance'], 'Missing final grading provenance'
    assert actual['registered_frame_count'] == 156
    assert actual['unique_drawn_pose_count'] == 155
    shared=actual['shared_drawn_poses']
    assert len(shared) == 1 and shared[0]['frames'] == ['down/6','recovering/1'], 'Unexpected shared-pose group'
    down=actual['clips']['down']['frames'][5]
    recovering=actual['clips']['recovering']['frames'][0]
    assert shared[0]['source_file'] == down['file'] == recovering['file'], 'Shared boundary source differs'
    assert shared[0]['rgba_sha256'] == down['rgba_sha256'] == recovering['rgba_sha256'], 'Shared boundary pixels differ'
    for key in ['rect','foot','body_height','hand','weapon_angle','weapon_behind','weapon_visible','second_hand','hand_occluders','clip_polygon']:
        assert down.get(key) == recovering.get(key), (key,'Shared boundary metadata differs')
    old = json.loads((registration.ROOT/'game/assets/v22/oichi/registration.json').read_text())
    assert set(actual['clips']) == set(old['clips'])
    assert actual['aliases'] == old['aliases']
    for name,clip in actual['clips'].items():
        assert clip['source_sha256'] != old['clips'][name]['source_sha256'], (name,'old source reused')
    print(f'PASS final {registration.PRODUCTION_ID} (v27): 26 clips / 156 registered frames / 155 unique poses / explicit down-recovery boundary / grading provenance / all aliases / no historical v22 source reuse')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--unit-only',action='store_true')
    args = parser.parse_args()
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(BuilderTests))
    if not result.wasSuccessful():
        raise SystemExit(1)
    if not args.unit_only:
        verify_final()

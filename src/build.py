"""Build the installable site from ../index.html into ./site. Usage: python3 build.py"""
import json, os, time
here=os.path.dirname(os.path.abspath(__file__))
cfg=json.load(open(os.path.join(here,'config.json')))
src=open(os.path.join(here,'..','index.html')).read()
src=src.replace('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.117.2/dist/umd/supabase.js','supabase.js')
src=src.replace('__SB_URL__',cfg.get('SB_URL','')).replace('__SB_KEY__',cfg.get('SB_KEY',''))
title_end=src.index('</title>')+len('</title>')
head_bits=src[:title_end]
body=src[title_end:]
ver=time.strftime('%Y%m%d%H%M%S')
page=f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
{head_bits}
<meta name="theme-color" content="#F2EBE1">
<meta name="description" content="Daily sadhana tracker for the 60-day Samyama preparation.">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" href="icon-192.png">
<link rel="apple-touch-icon" href="apple-touch-icon.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="Sadhana">
<style>:root{{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}}body{{margin:0}}img{{max-width:100%}}[hidden]{{display:none!important}}</style>
</head>
<body>
{body}
<script>if('serviceWorker' in navigator){{window.addEventListener('load',()=>navigator.serviceWorker.register('sw.js'))}}</script>
</body>
</html>
'''
open(os.path.join(here,'site','index.html'),'w').write(page)
open(os.path.join(here,'site','sw.js'),'w').write(open(os.path.join(here,'sw.template.js')).read().replace('__VERSION__',ver))
open(os.path.join(here,'site','.nojekyll'),'w').write('')
print('built version',ver,'cloud' if cfg.get('SB_URL') else 'local-only')

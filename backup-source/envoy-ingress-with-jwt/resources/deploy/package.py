from collections.abc import Mapping
from copy import deepcopy
from jinja2 import Template
from pathlib import Path
from shutil import copy2
import yaml

def enumerate_node(node):
  return node.items() if isinstance(node, Mapping) else enumerate(node)

def find(root, key, sep='/', return_tree=False):
  def __matched(root, path):
    if len(path) > len(root): return False
    edges = list(root)
    for i in reversed(path):
      if str(i) != '*' and str(i) != str(edges.pop()):
        return False
    return True

  def __find(node, test_path, traversed_path, tree):
    for k, v in enumerate_node(node):
      current_path = traversed_path + [k]
      if __matched(current_path, test_path):
        yield (current_path, tree + [v]) if return_tree else (current_path, v)
      if isinstance(v, Mapping) or isinstance(v, list):
        for result in __find(v,
                        test_path,
                        current_path,
                        tree + [v]):
          yield result
  test_key = key.split(sep) if isinstance(key, str) else key
  if test_key[0] == '#': test_key = test_key[1:]
  return __find(root, test_key, ['#'], [])

def put(root, path, value, overrideExistingType=False, sep='/', deleteKey=False):
  refpath = [x for x in (path.replace('#'+sep, '').split(sep) if isinstance(path, str) else path) if x != '#']
  reftree = []
  acc = root
  prev = None
  prevacc = {}
  for key in refpath:
    k = int(key) if isinstance(acc, list) else key
    if not isinstance(acc, Mapping) and not isinstance(acc, list):
      if overrideExistingType:
        prevacc[prev] = {}
        acc = prevacc[prev]
      else:
        raise TypeError('Using key `{0}` would result in a type mismatch on element `{2}` for path: {1}'.format(key, path, sep.join(['#'] + reftree)))
    reftree.append(key)
    if len(reftree) >= len(refpath):
      if deleteKey:
        result = acc.pop(k, None)
        return result
      else:
        acc[k] = value
        return root
    elif (isinstance(acc, Mapping) and k not in acc) or (isinstance(acc, list) and k >= len(acc)):
      acc[k] = {}
    prevacc = acc
    prev = key
    acc = acc[k]
  return root

def remove_keys(obj, values):
  output = deepcopy(obj)
  for x in values:
    output.pop(x, None)
  return output

def to_yaml(obj):
  return yaml.dump(obj).strip()

def add_route_circuit_breakers(vhost, healthplans):
  output = deepcopy(vhost)
  for matcher in output['routes']:
    if 'route' not in matcher or 'cluster' not in matcher['route'] or matcher['route']['cluster'] not in healthplans:
      continue
    route = matcher['route']
    if 'route' not in healthplans[route['cluster']]:
      continue
    cb = healthplans[route['cluster']]['route']
    for key, obj in cb.items():
      if key not in route:
        route[key] = obj
  return output

def make(mesh_config: Mapping, image_config: Mapping, src_root: Path, dst_root: Path):
  if '$ref' in image_config:
    config = yaml.safe_load((src_root/image_config['$ref']).open())
    for k in image_config.keys():
      if k.startswith('@'): config[k] = image_config[k]

    if '$append' in image_config and isinstance(image_config['$append'], Mapping):
      for key, value in image_config['$append'].items():
        results = list(find(config, key)) + [(['#', *key.split('/')], None)]
        dk, dv = results[0]
        print('{}.append(key=`{}`, value_type=`{}`)'.format(config['@env'], '/'.join([str(x) for x in dk]), type(value).__name__))
        if dv == None:
          put(config, dk, value)
        elif isinstance(dv, list):
          if isinstance(value, list): dv.extend(value)
          else: dv.append(value)
        else:
          put(config, dk, value)
    if '$emplace' in image_config and isinstance(image_config['$emplace'], Mapping):
      for key, value in image_config['$emplace'].items():
        results = list(find(config, key)) + [(['#', *key.split('/')], None)]
        dk, dv = results[0]
        print('{}.emplace(key=`{}`, is_new={})'.format(config['@env'], '/'.join([str(x) for x in dk]), len(results) == 1))
        put(config, dk, value)
    if '$remove' in image_config and isinstance(image_config['$remove'], list):
      for key in image_config['$remove']:
        results = list(find(config, key, return_tree=True)) + [(['#', *key.split('/')], [])]
        dk, dv = results[0]
        print('{}.remove(key=`{}`, exists={})'.format(config['@env'], '/'.join([str(x) for x in dk]), len(dv) > 0))
        if len(dv) > 1 and isinstance(dv[-2], Mapping): dv[-2].pop(dk[-1], None)
        elif len(dv) == 1: config.pop(key, None)
  else:
    config = image_config

  output = Template((src_root/'envoy.template.yaml').read_text())
  envoy_config = output.render(
    env_name = mesh_config['@env'],
    envoy = config,
    to_yaml = to_yaml,
    remove_keys = remove_keys,
    add_route_circuit_breakers = add_route_circuit_breakers,
  )
  (dst_root/'logs').mkdir()
  (dst_root/'conf').mkdir()
  (dst_root/'conf'/'envoy.yaml').write_text(envoy_config)
  for file in src_root.glob('*.lua'):
    copy2(file, dst_root/'conf')

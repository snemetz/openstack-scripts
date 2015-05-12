#!/usr/bin/env python

# Convert json to yaml

import sys
import json
import yaml

print yaml.dump(yaml.load(json.dumps(json.loads(open(sys.argv[1]).read()))), default_flow_style=False)


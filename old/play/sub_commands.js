#!/usr/bin/env node
'use strict';

var ArgumentParser = require('argparse').ArgumentParser;
var parser = new ArgumentParser({
  version: '0.0.1',
  addHelp: true,
  description: 'Argparse examples: sub-commands',
});

var subparsers = parser.addSubparsers({
  title: 'subcommands',
  dest: "subcommand_name"
});

parser.addArgument(
  [ '-z', '--zizzle'],
  {
    action : 'storeTrue',
    help : 'jamborie'
  }
);

var bar = subparsers.addParser('c1', {addHelp: true, help: 'c1 help', epilog : 'yo -- here is the shit!' });
bar.addArgument(
  [ '-f', '--foo' ],
  {
    action: 'store',
    help: 'foo3 bar3'
  }
);
var bar = subparsers.addParser(
  'c2',
  {aliases: ['co'], addHelp: true, help: 'c2 help'}
);
bar.addArgument(
  [ '-b', '--bar' ],
  {
    action: 'store',
    type: 'int',
    help: 'foo3 bar3'
  }
);
bar.addArgument(["files"], {nargs : "*"});
parser.printHelp();
console.log('-----------');

var args;
args = parser.parseArgs('-z c1 -f 2'.split(' '));
console.dir(args);
console.log('-----------');
args = parser.parseArgs('c2 -b 1'.split(' '));
console.dir(args);
console.log('-----------');
args = parser.parseArgs('co -b 1 yo'.split(' '));
console.dir(args);
console.log('-----------');
parser.parseArgs(['c1', '-h']);

#!/usr/bin/env ruby

$: << File.dirname(__FILE__)

require 'rubygems'
require 'bundler'
require 'storward'
load File.join(File.dirname(__FILE__), "config.rb")

Storward.run

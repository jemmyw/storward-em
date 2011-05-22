#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'storward'
load File.join(File.dirname(__FILE__), "config.rb")

Storward.run

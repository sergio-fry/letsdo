# frozen_string_literal: true

require 'stringio'

# A fake terminal stream: reports tty? true, buffers writes like StringIO.
class FakeTtyOut
  attr_reader :io

  def initialize
    @io = StringIO.new
  end

  def tty?
    true
  end

  def write(text)
    @io.write(text)
  end

  def puts(*args)
    @io.puts(*args)
  end

  def flush
    @io.flush
  end

  def string
    @io.string
  end
end

# A fake keyboard: reports tty? true and serves the scripted bytes.
class FakeTtyIn
  def initialize(bytes)
    @io = StringIO.new(bytes)
  end

  def tty?
    true
  end

  def eof?
    @io.eof?
  end

  def getc
    @io.getc
  end

  def wait_readable(_timeout)
    @io.eof? ? nil : true
  end

  def raw(&block)
    block.call
  end

  def noecho(&block)
    block.call
  end
end

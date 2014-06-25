require 'spec_helper'

module Concurrent

  describe Event do

    subject{ Event.new }

    context '#initialize' do

      it 'sets the state to unset' do
        subject.should_not be_set
      end
    end

    context '#set?' do

      it 'returns true when the event has been set' do
        subject.set
        subject.should be_set
      end

      it 'returns false if the event is unset' do
        subject.should_not be_set
      end
    end

    context '#set' do

      it 'triggers the event' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }
        subject.set
        latch.wait(1).should be_true
      end

      it 'sets the state to set' do
        subject.set
        subject.should be_set
      end
    end

    context '#try?' do

      it 'triggers the event if not already set' do
        subject.try?
        subject.should be_set
      end

      it 'returns true if not previously set' do
        subject.try?.should be_true
      end

      it 'returns false if previously set' do
        subject.set
        subject.try?.should be_false
      end
    end

    context '#reset' do

      it 'does not change the state of an unset event' do
        subject.reset
        subject.should_not be_set
      end

      it 'does not trigger an unset event' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }
        subject.reset
        latch.wait(0.1).should be_false
      end

      it 'does not interrupt waiting threads when event is unset' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }
        subject.reset
        latch.wait(0.1).should be_false
        subject.set
        latch.wait(0.1).should be_true
      end

      it 'returns true when called on an unset event' do
        subject.reset.should be_true
      end

      it 'sets the state of a set event to unset' do
        subject.set
        subject.should be_set
        subject.reset
        subject.should_not be_set
      end

      it 'returns true when called on a set event' do
        subject.set
        subject.should be_set
        subject.reset.should be_true
      end
    end

    #context '#pulse' do

      #it 'triggers an unset event' do
        #subject.reset
        #latch = CountDownLatch.new(1)
        #Thread.new{ subject.wait.tap{ puts "Boom!"; latch.count_down } }
        #subject.pulse
        #latch.wait(0.1).should be_true
      #end

      #it 'does nothing with a set event' do
        #subject.set
        #latch = CountDownLatch.new(1)
        #Thread.new{ subject.wait.tap{ latch.count_down } }
        #subject.pulse
        #latch.wait(0.1).should be_true
      #end

      #it 'leaves the event in the unset state' do
        #latch = CountDownLatch.new(1)
        #Thread.new{ subject.wait.tap{ latch.count_down } }
        #subject.pulse
        #latch.wait(0.1)
        #subject.should_not be_set
      #end
    #end

    context '#wait' do

      it 'returns immediately when the event has been set' do
        subject.reset
        latch = CountDownLatch.new(1)
        subject.set
        Thread.new{ subject.wait(1000).tap{ latch.count_down } }
        latch.wait(0.1).should be_true
      end

      it 'returns true once the event is set' do
        subject.set
        subject.wait.should be_true
      end

      it 'blocks indefinitely when the timer is nil' do
        subject.reset
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }
        latch.wait(0.1).should be_false
        subject.set
        latch.wait(0.1).should be_true
      end

      it 'stops waiting when the timer expires' do
        subject.reset
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait(0.2).tap{ latch.count_down } }
        latch.wait(0.1).should be_false
        latch.wait.should be_true
      end

      it 'returns false when the timer expires' do
        subject.reset
        subject.wait(1).should be_false
      end

      it 'triggers multiple waiting threads' do
        latch = CountDownLatch.new(5)
        subject.reset
        5.times{ Thread.new{ subject.wait; latch.count_down } }
        subject.set
        latch.wait(0.2).should be_true
      end

      it 'behaves appropriately if wait begins while #set is processing' do
        subject.reset
        latch = CountDownLatch.new(5)
        5.times{ Thread.new{ subject.wait(5) } }
        subject.set
        5.times{ Thread.new{ subject.wait; latch.count_down } }
        latch.wait(0.2).should be_true
      end
    end

    context 'spurious wake ups' do

      before(:each) do
        def subject.simulate_spurious_wake_up
          @mutex.synchronize do
            @condition.signal
            @condition.broadcast
          end
        end
      end

      it 'should resist to spurious wake ups without timeout' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait.tap{ latch.count_down } }

        sleep(0.1)
        subject.simulate_spurious_wake_up

        latch.wait(0.1).should be_false
      end

      it 'should resist to spurious wake ups with timeout' do
        latch = CountDownLatch.new(1)
        Thread.new{ subject.wait(0.3).tap{ latch.count_down } }

        sleep(0.1)
        subject.simulate_spurious_wake_up

        latch.wait(0.1).should be_false
        latch.wait(1).should be_true
      end
    end
  end
end

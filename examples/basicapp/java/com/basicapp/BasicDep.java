package com.basicapp.basicdep;

import java.time.Duration;
import java.util.concurrent.TimeUnit;

public class BasicDep {
    Duration d;
    public BasicDep(Duration d_) {
        this.d = d_;
    }
    public BasicDep() {
        this(Duration.ZERO);
    }
    public Duration getDuration() {
        return this.d;
    }
    public String toString() {
        // return this.d.toString();
        return Long.toString(this.toLong());
    }
    public long toLong() {
        // return TimeUnit.MILLISECONDS.convert(this.d.toMillis(), TimeUnit.MILLISECONDS);
        return TimeUnit.MILLISECONDS.convert(this.d);
    }
}
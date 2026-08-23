package com.sample;

/** Uses a lambda and string concatenation to reference java.lang.invoke. */
public class Sample {

  public static Runnable task(String name) {
    return () -> System.out.println("task " + name);
  }
}

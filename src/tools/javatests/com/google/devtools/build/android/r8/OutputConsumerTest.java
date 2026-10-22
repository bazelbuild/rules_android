// Copyright 2026 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
package com.google.devtools.build.android.r8;

import static com.google.common.truth.Truth.assertThat;
import static org.objectweb.asm.Opcodes.ACC_ABSTRACT;
import static org.objectweb.asm.Opcodes.ACC_BRIDGE;
import static org.objectweb.asm.Opcodes.ACC_INTERFACE;
import static org.objectweb.asm.Opcodes.ACC_PUBLIC;
import static org.objectweb.asm.Opcodes.ACC_STATIC;
import static org.objectweb.asm.Opcodes.ACC_SUPER;
import static org.objectweb.asm.Opcodes.INVOKESTATIC;
import static org.objectweb.asm.Opcodes.POP;
import static org.objectweb.asm.Opcodes.POP2;
import static org.objectweb.asm.Opcodes.RETURN;
import static org.objectweb.asm.Opcodes.V1_8;

import com.android.tools.r8.ByteDataView;
import com.android.tools.r8.Diagnostic;
import com.android.tools.r8.DiagnosticsHandler;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.devtools.build.android.r8.desugar.OutputConsumer;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.MethodVisitor;

/** Tests for the dependency metadata collected by {@link OutputConsumer}. */
@RunWith(JUnit4.class)
public class OutputConsumerTest {
  @Rule public final TemporaryFolder temp = new TemporaryFolder();

  private static final String COMPANION = "a/I$-CC";

  @Test
  public void dependencyMetadata() throws Exception {
    Path input =
        writeJar(
            ImmutableMap.of(
                // Interfaces which don't reference a companion class only record their header.
                "a/J.class",
                interfaceClass("a/J", mv -> {}),
                // An interface which references a companion class is visited in full.
                "a/K.class",
                interfaceClass("a/K", OutputConsumerTest::callCompanion)));
    RecordingCollector collector = new RecordingCollector();
    OutputConsumer consumer =
        new OutputConsumer(temp.getRoot().toPath().resolve("out.jar"), collector, input);
    DiagnosticsHandler handler =
        new DiagnosticsHandler() {
          @Override
          public void error(Diagnostic error) {
            throw new AssertionError(error.getDiagnosticMessage());
          }
        };
    accept(consumer, handler, "a/I$-CC", companionClass());
    // Long and double constants take two constant pool slots, and come before the class constant
    // for the companion class.
    accept(
        consumer,
        handler,
        "a/A",
        regularClass(
            "a/A",
            mv -> {
              mv.visitLdcInsn(1L);
              mv.visitInsn(POP2);
              mv.visitLdcInsn(2.0);
              mv.visitInsn(POP2);
              callCompanion(mv);
            }));
    // A string constant with the companion class name is not a reference to it.
    accept(
        consumer,
        handler,
        "a/S",
        regularClass(
            "a/S",
            mv -> {
              mv.visitLdcInsn(COMPANION);
              mv.visitInsn(POP);
            }));
    accept(consumer, handler, "a/L", interfaceClass("a/L", OutputConsumerTest::callCompanion));
    consumer.finished(handler);

    // Extended interfaces are only recorded from the input, and companion classes which the input
    // already assumed are not recorded again.
    assertThat(collector.calls)
        .containsExactly(
            "recordExtendedInterfaces a/J [a/I]",
            "recordExtendedInterfaces a/K [a/I]",
            "recordDefaultMethods a/I 2",
            "assumeCompanionClass a/A a/I$-CC",
            "assumeCompanionClass a/L a/I$-CC");
  }

  private static void accept(
      OutputConsumer consumer, DiagnosticsHandler handler, String binaryName, byte[] bytes) {
    consumer.accept(ByteDataView.of(bytes), "L" + binaryName + ";", handler);
  }

  private static void callCompanion(MethodVisitor mv) {
    mv.visitMethodInsn(INVOKESTATIC, COMPANION, "m", "()V", false);
  }

  private static byte[] companionClass() {
    ClassWriter cw = new ClassWriter(ClassWriter.COMPUTE_MAXS);
    cw.visit(V1_8, ACC_PUBLIC | ACC_SUPER, COMPANION, null, "java/lang/Object", null);
    addStaticMethod(cw, "m", ACC_PUBLIC | ACC_STATIC, mv -> {});
    addStaticMethod(cw, "n", ACC_PUBLIC | ACC_STATIC, mv -> {});
    // Bridges are not counted as default methods.
    addStaticMethod(cw, "b", ACC_PUBLIC | ACC_STATIC | ACC_BRIDGE, mv -> {});
    cw.visitEnd();
    return cw.toByteArray();
  }

  private static byte[] regularClass(String name, Consumer<MethodVisitor> code) {
    ClassWriter cw = new ClassWriter(ClassWriter.COMPUTE_MAXS);
    cw.visit(V1_8, ACC_PUBLIC | ACC_SUPER, name, null, "java/lang/Object", null);
    addStaticMethod(cw, "f", ACC_PUBLIC | ACC_STATIC, code);
    cw.visitEnd();
    return cw.toByteArray();
  }

  private static byte[] interfaceClass(String name, Consumer<MethodVisitor> code) {
    ClassWriter cw = new ClassWriter(ClassWriter.COMPUTE_MAXS);
    cw.visit(
        V1_8,
        ACC_PUBLIC | ACC_INTERFACE | ACC_ABSTRACT,
        name,
        null,
        "java/lang/Object",
        new String[] {"a/I"});
    addStaticMethod(cw, "f", ACC_PUBLIC | ACC_STATIC, code);
    cw.visitEnd();
    return cw.toByteArray();
  }

  private static void addStaticMethod(
      ClassWriter cw, String name, int access, Consumer<MethodVisitor> code) {
    MethodVisitor mv = cw.visitMethod(access, name, "()V", null, null);
    mv.visitCode();
    code.accept(mv);
    mv.visitInsn(RETURN);
    mv.visitMaxs(0, 0);
    mv.visitEnd();
  }

  private Path writeJar(Map<String, byte[]> entries) throws IOException {
    Path jar = temp.newFile("input.jar").toPath();
    try (OutputStream out = Files.newOutputStream(jar);
        ZipOutputStream zip = new ZipOutputStream(out)) {
      for (Map.Entry<String, byte[]> entry : entries.entrySet()) {
        zip.putNextEntry(new ZipEntry(entry.getKey()));
        zip.write(entry.getValue());
        zip.closeEntry();
      }
    }
    return jar;
  }

  private static class RecordingCollector implements DependencyCollector {
    private final List<String> calls = new ArrayList<>();

    @Override
    public void assumeCompanionClass(String origin, String target) {
      calls.add("assumeCompanionClass " + origin + " " + target);
    }

    @Override
    public void missingImplementedInterface(String origin, String target) {
      calls.add("missingImplementedInterface " + origin + " " + target);
    }

    @Override
    public void recordExtendedInterfaces(String origin, String... targets) {
      calls.add("recordExtendedInterfaces " + origin + " " + ImmutableList.copyOf(targets));
    }

    @Override
    public void recordDefaultMethods(String origin, int count) {
      calls.add("recordDefaultMethods " + origin + " " + count);
    }

    @Override
    public byte[] toByteArray() {
      return null;
    }
  }
}

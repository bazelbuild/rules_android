#include <string.h>
#include <jni.h>

jstring
Java_com_example_sampleapp_SampleApp_getString(JNIEnv* env, jobject thiz) {
  return (*env)->NewStringUTF(env, "Native String!");
}

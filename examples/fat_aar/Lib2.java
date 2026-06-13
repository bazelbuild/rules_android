package com.example.fat_aar;

public class Lib2 {
    private Lib1 lib1 = new Lib1();

    public String getCombinedMessage() {
        return "Lib2 says: " + lib1.getMessage();
    }
}

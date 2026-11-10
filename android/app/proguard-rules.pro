# ML Kit (распознавание лица для «Келдим») создаёт регистраторы своих компонентов
# через рефлексию — по именам классов из манифеста. R8 в release выбрасывал их
# конструкторы: компоненты не регистрировались, InputImage.fromByteArray падал
# с NullPointerException на каждом кадре, и автоснимок не срабатывал ни разу.
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}

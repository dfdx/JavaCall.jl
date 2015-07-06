
#get the JNI signature string for a method, given its 
#return type and argument types
function method_signature(rettype, argtypes...)
    s=IOBuffer()
    write(s, "(")
    for arg in argtypes
        write(s, signature(arg))
    end
    write(s, ")")
    write(s, signature(rettype))
    return takebuf_string(s)
end


#get the JNI signature string for a given type
function signature(arg::Type)
    if is(arg, jboolean)
        return "Z"
    elseif is(arg, jbyte)
        return "B"
    elseif is(arg, jchar)
        return "C"
    elseif is(arg, jint)
        return "I"
    elseif is(arg, jlong)
        return "J"
    elseif is(arg, jfloat)
        return "F"
    elseif is(arg, jdouble)
        return "D"
    elseif is(arg, Void) 
        return "V"
    elseif issubtype(arg, Array) 
        return string("[", signature(eltype(arg)))
    else
        error("Unknown type: $arg")
    end
end

signature(class::JavaClass) = string("L", jniclassname(class.classname), ";")

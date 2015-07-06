



function jnew(class::JavaClass, argtypes::Tuple, args...) 
    sig = method_signature(Void, argtypes...)
    jmethodId = ccall(jnifunc.GetMethodID, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), penv, class.ptr, utf8("<init>"), sig)
    if (jmethodId == C_NULL) 
        error("No constructor for $T with signature $sig")
    end 
    return  _jcall(metaclass(T), jmethodId, jnifunc.NewObjectA, JavaObject{T}, argtypes, args...)
end

package cc.ekblad.toml.transcoding

import cc.ekblad.toml.model.TomlException
import cc.ekblad.toml.model.TomlValue
import cc.ekblad.toml.util.KotlinName
import cc.ekblad.toml.util.TomlName
import kotlin.reflect.KClass
import kotlin.reflect.KProperty1
import kotlin.reflect.KVisibility
import kotlin.reflect.full.declaredMemberProperties
import kotlin.reflect.jvm.isAccessible

class TomlEncoder internal constructor(
    private val encoders: Map<KClass<*>, List<TomlEncoder.(Any) -> TomlValue>>,
    private val mappings: Map<KClass<*>, Map<KotlinName, TomlName>>,
) {
    /**
     * Thrown by an encoder function to indicate that it can't encode the given value, and that
     * the next encoder function for the source type should be given a chance instead.
     */
    internal object Pass : Throwable()

    /**
     * Called by an encoder function to indicate that it can't encode the given value, and that
     * the next encoder function for the source type should be given a chance instead.
     */
    fun pass(): Nothing = throw Pass

    internal fun mappingFor(type: KClass<*>): Map<KotlinName, TomlName> =
        mappings[type] ?: emptyMap()

    internal fun encoderFor(type: KClass<*>): ((Any) -> TomlValue)? =
        encoders[type]?.let { encodersForType ->
            return encoder@{ value ->
                encodersForType.forEach { encode ->
                    try {
                        return@encoder this.encode(value)
                    } catch (e: Pass) {
                        /* no-op */
                    }
                }
                throw Pass
            }
        }
}

/**
 * Encode the given value using the receiver encoder.
 */
fun TomlEncoder.encode(value: Any): TomlValue {
    encoderFor(value::class)?.let { encode ->
        try {
            return@encode encode(value)
        } catch (e: TomlEncoder.Pass) {
            /* no-op */
        }
    }
    return when {
        value is Map<*, *> -> fromMap(value)
        value is Iterable<*> -> TomlValue.List(value.mapNotNull { it?.let(::encode) })
        value::class.isData -> fromDataClass(value)
        else -> throw TomlException.EncodingError(value, null)
    }
}

private fun TomlEncoder.fromMap(value: Map<*, *>): TomlValue {
    val entries = value.mapNotNull { (key, value) ->
        value?.let { key.toString() to encode(it) }
    }
    return TomlValue.Map(entries.toMap())
}

private fun TomlEncoder.fromDataClass(value: Any): TomlValue.Map {
    val tomlNamesByParameterName = mappingFor(value::class)
    val fields = value::class.declaredMemberProperties.mapNotNull { prop ->
        if (value::class.visibility == KVisibility.PRIVATE) {
            prop.isAccessible = true
        }

        @Suppress("UNCHECKED_CAST")
        (prop as KProperty1<Any, Any?>).get(value)?.let {
            val name = tomlNamesByParameterName[prop.name] ?: prop.name
            name to encode(it)
        }
    }
    return TomlValue.Map(fields.toMap())
}

package com.footverse.mapstruct;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.mapstruct.Mapper;
import org.springframework.stereotype.Component;

/**
 * Verifies that MapStruct annotation processing generates a mapper implementation at compile
 * time and that the global {@code componentModel = "spring"} setting makes it a Spring bean.
 *
 * <p>Build/infrastructure check only (test scope); no feature mapper is created.</p>
 */
class MapStructConfigurationTest {

    /**
     * The generated implementation exists, is a Spring {@link Component}, and maps correctly.
     *
     * @throws Exception if the generated implementation cannot be loaded or instantiated
     */
    @Test
    void generatesSpringComponentMapperImplementation() throws Exception {
        Class<?> implClass = Class.forName("com.footverse.mapstruct.SampleMapperImpl");

        assertThat(implClass.isAnnotationPresent(Component.class))
                .as("componentModel=spring must annotate the generated impl with @Component")
                .isTrue();

        SampleMapper mapper = (SampleMapper) implClass.getDeclaredConstructor().newInstance();
        SampleTarget target = mapper.toTarget(new SampleSource("Nike", 42));

        assertThat(target.name()).isEqualTo("Nike");
        assertThat(target.size()).isEqualTo(42);
    }
}

/**
 * Test-only source type for the MapStruct verification.
 *
 * @param name a name
 * @param size a size
 */
record SampleSource(String name, int size) {
}

/**
 * Test-only target type for the MapStruct verification.
 *
 * @param name a name
 * @param size a size
 */
record SampleTarget(String name, int size) {
}

/**
 * Test-only mapper used solely to verify annotation processing and the Spring component model.
 */
@Mapper
interface SampleMapper {

    /**
     * Maps a {@link SampleSource} to a {@link SampleTarget}.
     *
     * @param source the source
     * @return the mapped target
     */
    SampleTarget toTarget(SampleSource source);
}

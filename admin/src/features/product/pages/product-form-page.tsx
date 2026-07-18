import { Box, Button, CircularProgress, Snackbar, Tab, Tabs, Typography } from '@mui/material';
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactElement,
  type ReactNode,
} from 'react';
import { useLocation, useNavigate } from 'react-router-dom';

import { AppError } from '@/core/error/app-error';
import { ROUTES } from '@/core/router/routes';
import type { BrandResponse } from '@/features/brand/models/brand-response';
import type { BrandRepository } from '@/features/brand/repositories/brand-repository';
import type { CategoryResponse } from '@/features/category/models/category-response';
import type { CategoryRepository } from '@/features/category/repositories/category-repository';

import { ImageForm, type ImageFormErrors, type ImageFormValues } from '../components/image-form';
import { ImageList } from '../components/image-list';
import {
  ProductForm,
  type ProductFormErrors,
  type ProductFormValues,
} from '../components/product-form';
import {
  VariantForm,
  type VariantFormErrors,
  type VariantFormValues,
} from '../components/variant-form';
import { VariantList } from '../components/variant-list';
import { useProductMutation } from '../hooks/use-product-mutation';
import type { AdminProductDetailResponse } from '../models/admin-product-detail-response';
import type { AdminProductVariantResponse } from '../models/admin-product-variant-response';
import type { ProductImageResponse } from '../models/product-image-response';
import type { ProductRepository } from '../repositories/product-repository';
import {
  productImageValidators,
  productValidators,
  productVariantValidators,
} from '../validators/product-validators';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

interface ProductFormPageProps {
  readonly productRepository: ProductRepository;
  readonly categoryRepository: CategoryRepository;
  readonly brandRepository: BrandRepository;
}

interface NavigationState {
  readonly productId?: number;
}

type VariantDialogState =
  | { readonly mode: 'create' }
  | { readonly mode: 'edit'; readonly variant: AdminProductVariantResponse };

type ImageDialogState =
  { readonly mode: 'create' } | { readonly mode: 'edit'; readonly image: ProductImageResponse };

type ProductEditTab = 'general' | 'variants' | 'images';

interface ProductEditTabPanelProps {
  readonly tab: ProductEditTab;
  readonly activeTab: ProductEditTab;
  readonly children: ReactNode;
}

/**
 * A tab panel that stays mounted and is only visually hidden when inactive
 * (`display: none`), never conditionally rendered — switching tabs must not
 * mount/unmount `ProductForm` / `VariantList` / `ImageList` or their input
 * state (UX Enhancement: Product Edit tabs).
 */
function ProductEditTabPanel({ tab, activeTab, children }: ProductEditTabPanelProps): ReactElement {
  return (
    <Box
      role="tabpanel"
      hidden={activeTab !== tab}
      sx={{ display: activeTab === tab ? 'block' : 'none' }}
    >
      {children}
    </Box>
  );
}

function emptyProductValues(): ProductFormValues {
  return { name: '', description: '', basePrice: '', categoryId: '', brandId: '' };
}

function toProductValues(product: AdminProductDetailResponse): ProductFormValues {
  return {
    name: product.name,
    description: product.description ?? '',
    basePrice: String(product.basePrice),
    categoryId: String(product.categoryId),
    brandId: String(product.brandId),
  };
}

function emptyVariantValues(): VariantFormValues {
  return {
    color: '',
    size: '',
    sku: '',
    stockQuantity: '',
    status: 'ACTIVE',
    priceOverride: '',
    costPrice: '',
  };
}

function toVariantValues(variant: AdminProductVariantResponse): VariantFormValues {
  return {
    color: variant.color,
    size: variant.size,
    sku: variant.sku,
    stockQuantity: String(variant.stockQuantity),
    status: variant.status,
    // The raw override (not the resolved `price`) — undefined/null means the
    // variant follows basePrice; never inferred from a price comparison.
    priceOverride:
      variant.priceOverride !== undefined && variant.priceOverride !== null
        ? String(variant.priceOverride)
        : '',
    costPrice: String(variant.costPrice),
  };
}

function emptyImageValues(): ImageFormValues {
  return { imageUrl: '', displayOrder: '', isPrimary: false };
}

function toImageValues(image: ProductImageResponse): ImageFormValues {
  return {
    imageUrl: image.imageUrl,
    displayOrder: String(image.displayOrder),
    isPrimary: image.isPrimary,
  };
}

/**
 * The create / edit product screen — the React analog of the Flutter product
 * form screen (sprint-11-plan Task 04), mirroring `BrandFormPage` (Sprint 10)
 * for the product core and extending it with in-page variant / image
 * management (Task 03's `ProductListPage` navigates here with `productId` in
 * router `state`, or with none for create).
 *
 * Two independent `useProductMutation` instances are wired for two different
 * reload meanings (react-guidelines §Hook Lifecycle — no cross-hook call,
 * every reload goes through a callback):
 *  - `coreMutation`'s reload navigates back to the product list — the create
 *    and edit round-trip for the product's own fields (Task 04 DoD).
 *  - `aggregateMutation`'s reload re-fetches the product detail in place — a
 *    variant/image write stays on this page so its server-decided state
 *    (including the one-primary flag and effective prices) re-renders
 *    without navigating away (Design Decision 4 / Server Authoritative).
 * Variant and image management only exists in edit mode: a product must
 * already have an id before it can own variants or images.
 */
export function ProductFormPage({
  productRepository,
  categoryRepository,
  brandRepository,
}: ProductFormPageProps): ReactElement {
  const location = useLocation();
  const navigate = useNavigate();
  const editingProductId = (location.state as NavigationState | null)?.productId ?? null;

  // ----- Product detail (edit mode only) -----
  const [product, setProduct] = useState<AdminProductDetailResponse | null>(null);
  const [detailStatus, setDetailStatus] = useState<'idle' | 'loading' | 'ready' | 'error'>(
    editingProductId !== null ? 'loading' : 'idle',
  );
  const [detailError, setDetailError] = useState<AppError | null>(null);
  const hasSeededCoreValues = useRef(false);

  const loadDetail = useCallback(async (): Promise<void> => {
    if (editingProductId === null) {
      return;
    }
    setDetailStatus('loading');
    setDetailError(null);
    try {
      const detail = await productRepository.get(editingProductId);
      setProduct(detail);
      setDetailStatus('ready');
    } catch (caught) {
      setDetailError(
        caught instanceof AppError ? caught : new AppError({ message: UNEXPECTED_MESSAGE }),
      );
      setDetailStatus('error');
    }
  }, [editingProductId, productRepository]);

  useEffect(() => {
    void loadDetail();
  }, [loadDetail]);

  // ----- Category / brand options (read-only, reused Sprint 10 repositories) -----
  const [categories, setCategories] = useState<readonly CategoryResponse[]>([]);
  const [brands, setBrands] = useState<readonly BrandResponse[]>([]);
  const [optionsStatus, setOptionsStatus] = useState<'loading' | 'ready' | 'error'>('loading');
  // Guards against a stale response overwriting a newer one (the Flutter
  // "notify-after-dispose" precedent, adapted to a retry-able load): only the
  // most recently started request may commit its result.
  const optionsRequestId = useRef(0);

  const loadOptions = useCallback(async (): Promise<void> => {
    const requestId = ++optionsRequestId.current;
    setOptionsStatus('loading');
    try {
      const [categoryList, brandList] = await Promise.all([
        categoryRepository.list(),
        brandRepository.list(),
      ]);
      if (optionsRequestId.current === requestId) {
        setCategories(categoryList);
        setBrands(brandList);
        setOptionsStatus('ready');
      }
    } catch {
      if (optionsRequestId.current === requestId) {
        setOptionsStatus('error');
      }
    }
  }, [categoryRepository, brandRepository]);

  useEffect(() => {
    void loadOptions();
  }, [loadOptions]);

  // ----- Snackbars (shared across the product core + variant + image actions) -----
  const [successMessage, setSuccessMessage] = useState<string>();
  const [errorMessage, setErrorMessage] = useState<string>();

  // ----- Section tab (UX Enhancement, presentation-only: layout, not routing) -----
  const [activeTab, setActiveTab] = useState<ProductEditTab>('general');

  // ----- Product core form -----
  const navigateToListReload = useCallback((): Promise<void> => {
    navigate(ROUTES.products, {
      state: { successMessage: editingProductId !== null ? 'Product updated' : 'Product created' },
    });
    return Promise.resolve();
  }, [navigate, editingProductId]);

  const coreMutation = useProductMutation(productRepository, navigateToListReload);

  const [values, setValues] = useState<ProductFormValues>(emptyProductValues);
  const [errors, setErrors] = useState<ProductFormErrors>({});
  const nameInputRef = useRef<HTMLInputElement>(null);
  const descriptionInputRef = useRef<HTMLInputElement>(null);
  const basePriceInputRef = useRef<HTMLInputElement>(null);
  const categoryInputRef = useRef<HTMLInputElement>(null);
  const brandInputRef = useRef<HTMLInputElement>(null);

  // Seed the core form from the first successful detail load only — a later
  // reload (triggered by a variant/image save) must not clobber in-progress
  // edits to the product's own fields.
  useEffect(() => {
    if (product !== null && !hasSeededCoreValues.current) {
      setValues(toProductValues(product));
      hasSeededCoreValues.current = true;
    }
  }, [product]);

  function handleFieldChange(field: keyof ProductFormValues, value: string): void {
    setValues((prev) => ({ ...prev, [field]: value }));
  }

  async function handleCoreSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    if (pageMutating) {
      return;
    }
    const nameError = productValidators.name(values.name);
    const descriptionError = productValidators.description(values.description);
    const basePriceError = productValidators.basePrice(values.basePrice);
    const categoryIdError = productValidators.categoryId(values.categoryId);
    const brandIdError = productValidators.brandId(values.brandId);
    setErrors({
      name: nameError,
      description: descriptionError,
      basePrice: basePriceError,
      categoryId: categoryIdError,
      brandId: brandIdError,
    });
    if (nameError !== undefined) {
      nameInputRef.current?.focus();
      return;
    }
    if (descriptionError !== undefined) {
      descriptionInputRef.current?.focus();
      return;
    }
    if (basePriceError !== undefined) {
      basePriceInputRef.current?.focus();
      return;
    }
    if (categoryIdError !== undefined) {
      categoryInputRef.current?.focus();
      return;
    }
    if (brandIdError !== undefined) {
      brandInputRef.current?.focus();
      return;
    }

    const request = {
      name: values.name.trim(),
      description: values.description.trim().length > 0 ? values.description.trim() : undefined,
      basePrice: Number(values.basePrice),
      categoryId: Number(values.categoryId),
      brandId: Number(values.brandId),
    };
    try {
      if (editingProductId !== null) {
        await coreMutation.update(editingProductId, request);
      } else {
        await coreMutation.create(request);
      }
    } catch (error) {
      setErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  // ----- Variant / image aggregate mutations (edit mode only; reload = re-fetch detail in place) -----
  const aggregateMutation = useProductMutation(productRepository, loadDetail);

  // Page-level single-flight: `coreMutation` and `aggregateMutation` are two
  // independent hook instances (react-guidelines §Hook Lifecycle — no
  // cross-hook call), so each is single-flight on its own but not against the
  // other. This page never lets the two run concurrently: while either is in
  // flight, every write affordance on the page — the product form submit and
  // every variant/image add/edit/submit — is disabled.
  const pageMutating = coreMutation.isMutating || aggregateMutation.isMutating;

  // ----- Variant dialog -----
  const [variantDialog, setVariantDialog] = useState<VariantDialogState | null>(null);
  const [variantValues, setVariantValues] = useState<VariantFormValues>(emptyVariantValues);
  const [variantErrors, setVariantErrors] = useState<VariantFormErrors>({});
  const colorInputRef = useRef<HTMLInputElement>(null);
  const sizeInputRef = useRef<HTMLInputElement>(null);
  const skuInputRef = useRef<HTMLInputElement>(null);
  const stockQuantityInputRef = useRef<HTMLInputElement>(null);
  const priceOverrideInputRef = useRef<HTMLInputElement>(null);
  const costPriceInputRef = useRef<HTMLInputElement>(null);

  function openCreateVariant(): void {
    setVariantValues(emptyVariantValues());
    setVariantErrors({});
    setVariantDialog({ mode: 'create' });
  }

  function openEditVariant(variant: AdminProductVariantResponse): void {
    setVariantValues(toVariantValues(variant));
    setVariantErrors({});
    setVariantDialog({ mode: 'edit', variant });
  }

  function handleVariantFieldChange(field: keyof VariantFormValues, value: string): void {
    setVariantValues((prev) => ({ ...prev, [field]: value }));
  }

  async function handleVariantSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    if (pageMutating || editingProductId === null || variantDialog === null) {
      return;
    }
    const colorError = productVariantValidators.color(variantValues.color);
    const sizeError = productVariantValidators.size(variantValues.size);
    const skuError = productVariantValidators.sku(variantValues.sku);
    const stockQuantityError = productVariantValidators.stockQuantity(variantValues.stockQuantity);
    const priceOverrideError = productVariantValidators.priceOverride(variantValues.priceOverride);
    const costPriceError = productVariantValidators.costPrice(variantValues.costPrice);
    setVariantErrors({
      color: colorError,
      size: sizeError,
      sku: skuError,
      stockQuantity: stockQuantityError,
      priceOverride: priceOverrideError,
      costPrice: costPriceError,
    });
    if (colorError !== undefined) {
      colorInputRef.current?.focus();
      return;
    }
    if (sizeError !== undefined) {
      sizeInputRef.current?.focus();
      return;
    }
    if (skuError !== undefined) {
      skuInputRef.current?.focus();
      return;
    }
    if (stockQuantityError !== undefined) {
      stockQuantityInputRef.current?.focus();
      return;
    }
    if (priceOverrideError !== undefined) {
      priceOverrideInputRef.current?.focus();
      return;
    }
    if (costPriceError !== undefined) {
      costPriceInputRef.current?.focus();
      return;
    }

    const request = {
      color: variantValues.color.trim(),
      size: variantValues.size.trim(),
      sku: variantValues.sku.trim(),
      stockQuantity: Number(variantValues.stockQuantity),
      status: variantValues.status,
      priceOverride:
        variantValues.priceOverride.trim().length > 0
          ? Number(variantValues.priceOverride)
          : undefined,
      costPrice: Number(variantValues.costPrice),
    };
    try {
      if (variantDialog.mode === 'edit') {
        await aggregateMutation.updateVariant(editingProductId, variantDialog.variant.id, request);
      } else {
        await aggregateMutation.createVariant(editingProductId, request);
      }
      setVariantDialog(null);
      setSuccessMessage(variantDialog.mode === 'edit' ? 'Variant updated' : 'Variant created');
    } catch (error) {
      setErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  // ----- Image dialog -----
  const [imageDialog, setImageDialog] = useState<ImageDialogState | null>(null);
  const [imageValues, setImageValues] = useState<ImageFormValues>(emptyImageValues);
  const [imageErrors, setImageErrors] = useState<ImageFormErrors>({});
  const imageUrlInputRef = useRef<HTMLInputElement>(null);
  const displayOrderInputRef = useRef<HTMLInputElement>(null);

  function openCreateImage(): void {
    setImageValues(emptyImageValues());
    setImageErrors({});
    setImageDialog({ mode: 'create' });
  }

  function openEditImage(image: ProductImageResponse): void {
    setImageValues(toImageValues(image));
    setImageErrors({});
    setImageDialog({ mode: 'edit', image });
  }

  function handleImageFieldChange(field: 'imageUrl' | 'displayOrder', value: string): void {
    setImageValues((prev) => ({ ...prev, [field]: value }));
  }

  function handleImagePrimaryChange(isPrimary: boolean): void {
    setImageValues((prev) => ({ ...prev, isPrimary }));
  }

  async function handleImageSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    if (pageMutating || editingProductId === null || imageDialog === null) {
      return;
    }
    const imageUrlError = productImageValidators.imageUrl(imageValues.imageUrl);
    const displayOrderError = productImageValidators.displayOrder(imageValues.displayOrder);
    setImageErrors({ imageUrl: imageUrlError, displayOrder: displayOrderError });
    if (imageUrlError !== undefined) {
      imageUrlInputRef.current?.focus();
      return;
    }
    if (displayOrderError !== undefined) {
      displayOrderInputRef.current?.focus();
      return;
    }

    const request = {
      imageUrl: imageValues.imageUrl.trim(),
      displayOrder: Number(imageValues.displayOrder),
      isPrimary: imageValues.isPrimary,
    };
    try {
      if (imageDialog.mode === 'edit') {
        await aggregateMutation.updateImage(editingProductId, imageDialog.image.id, request);
      } else {
        await aggregateMutation.createImage(editingProductId, request);
      }
      setImageDialog(null);
      setSuccessMessage(imageDialog.mode === 'edit' ? 'Image updated' : 'Image created');
    } catch (error) {
      setErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  const isDetailReady = editingProductId === null || detailStatus === 'ready';

  return (
    <Box>
      <Typography variant="h4" component="h1" gutterBottom>
        {editingProductId !== null ? 'Edit product' : 'New product'}
      </Typography>

      {editingProductId !== null && detailStatus === 'loading' && (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
          <CircularProgress />
        </Box>
      )}

      {editingProductId !== null && detailStatus === 'error' && (
        <Box sx={{ textAlign: 'center', p: 4 }}>
          <Typography color="text.secondary" sx={{ mb: 2 }}>
            {detailError?.message ?? UNEXPECTED_MESSAGE}
          </Typography>
          <Button variant="contained" onClick={() => void loadDetail()}>
            Retry
          </Button>
        </Box>
      )}

      {isDetailReady && optionsStatus === 'error' && (
        <Box sx={{ textAlign: 'center', p: 4 }}>
          <Typography color="text.secondary" sx={{ mb: 2 }}>
            {UNEXPECTED_MESSAGE}
          </Typography>
          <Button variant="contained" onClick={() => void loadOptions()}>
            Retry
          </Button>
        </Box>
      )}

      {isDetailReady && optionsStatus === 'loading' && (
        <Box sx={{ display: 'flex', justifyContent: 'center', p: 4 }}>
          <CircularProgress />
        </Box>
      )}

      {isDetailReady && optionsStatus === 'ready' && (
        <>
          {/* The tab bar (and hence the Variants / Images sections) only makes
              sense once the product exists — a new product has no id yet to
              own variants or images. Create mode renders the General section
              alone, unchanged from before this UX enhancement; `activeTab`
              stays at its initial 'general' value throughout since there is
              no Tabs control to change it. */}
          {editingProductId !== null && product !== null && (
            <Tabs
              value={activeTab}
              onChange={(_event, value: ProductEditTab) => setActiveTab(value)}
              sx={{ mb: 3 }}
            >
              <Tab label="General" value="general" />
              <Tab label="Variants" value="variants" />
              <Tab label="Images" value="images" />
            </Tabs>
          )}

          <ProductEditTabPanel tab="general" activeTab={activeTab}>
            <ProductForm
              values={values}
              errors={errors}
              disabled={pageMutating}
              submitLabel={editingProductId !== null ? 'Save' : 'Create'}
              categories={categories}
              brands={brands}
              nameInputRef={nameInputRef}
              descriptionInputRef={descriptionInputRef}
              basePriceInputRef={basePriceInputRef}
              categoryInputRef={categoryInputRef}
              brandInputRef={brandInputRef}
              onFieldChange={handleFieldChange}
              onSubmit={(event) => {
                void handleCoreSubmit(event);
              }}
              onCancel={() => navigate(ROUTES.products)}
            />
          </ProductEditTabPanel>

          {editingProductId !== null && product !== null && (
            <>
              <ProductEditTabPanel tab="variants" activeTab={activeTab}>
                <VariantList
                  variants={product.variants}
                  disabled={pageMutating}
                  onAdd={openCreateVariant}
                  onEdit={openEditVariant}
                />
              </ProductEditTabPanel>

              <ProductEditTabPanel tab="images" activeTab={activeTab}>
                <ImageList
                  images={product.images}
                  disabled={pageMutating}
                  onAdd={openCreateImage}
                  onEdit={openEditImage}
                />
              </ProductEditTabPanel>
            </>
          )}
        </>
      )}

      {variantDialog !== null && (
        <VariantForm
          open
          title={variantDialog.mode === 'edit' ? 'Edit variant' : 'Add variant'}
          values={variantValues}
          errors={variantErrors}
          disabled={pageMutating}
          submitLabel={variantDialog.mode === 'edit' ? 'Save' : 'Create'}
          colorInputRef={colorInputRef}
          sizeInputRef={sizeInputRef}
          skuInputRef={skuInputRef}
          stockQuantityInputRef={stockQuantityInputRef}
          priceOverrideInputRef={priceOverrideInputRef}
          costPriceInputRef={costPriceInputRef}
          onFieldChange={handleVariantFieldChange}
          onSubmit={(event) => {
            void handleVariantSubmit(event);
          }}
          onCancel={() => setVariantDialog(null)}
        />
      )}

      {imageDialog !== null && (
        <ImageForm
          open
          title={imageDialog.mode === 'edit' ? 'Edit image' : 'Add image'}
          values={imageValues}
          errors={imageErrors}
          disabled={pageMutating}
          submitLabel={imageDialog.mode === 'edit' ? 'Save' : 'Create'}
          imageUrlInputRef={imageUrlInputRef}
          displayOrderInputRef={displayOrderInputRef}
          onFieldChange={handleImageFieldChange}
          onPrimaryChange={handleImagePrimaryChange}
          onSubmit={(event) => {
            void handleImageSubmit(event);
          }}
          onCancel={() => setImageDialog(null)}
        />
      )}

      <Snackbar
        open={successMessage !== undefined}
        autoHideDuration={4000}
        onClose={() => setSuccessMessage(undefined)}
        message={successMessage}
      />
      <Snackbar
        open={errorMessage !== undefined}
        autoHideDuration={6000}
        onClose={() => setErrorMessage(undefined)}
        message={errorMessage}
      />
    </Box>
  );
}
